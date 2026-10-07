# Disposable guest only. This script is composed into secure-uki-pcr.nix;
# machine/driver/shared helpers and closure constants come from the fixture.
import base64

runtime = json.loads(machine.succeed("cat /etc/secure-uki.json"))
tools = runtime["tools"]
policy_dir = "/var/lib/secure-uki/pcr-signing"
machine.succeed("rm /nix/var/nix/gcroots/vm-fixture-c; install -d -m 0700 /persist/pcr-archive")


def current_manifest():
    return json.loads(machine.succeed("cat /var/lib/secure-uki/manifest.json"))


def approved_selection():
    select_probe_image(machine, current_manifest()["default"])


def auto_root(closure, managed=True):
    machine.wait_for_unit("multi-user.target", timeout=90)
    console = machine.get_console_log()
    assert "Please enter passphrase" not in console, "unattended boot asked for recovery"
    machine.succeed("test $(readlink -f /run/booted-system) = " + closure)
    machine.succeed("findmnt -T /nix/store -n -o SOURCE,FSTYPE | grep -F /dev/mapper/encrypted | grep -F btrfs")
    if managed:
        machine.wait_until_succeeds("test $(systemctl show secure-uki-confirm -p SubState --value) = exited")
    else:
        machine.succeed("systemctl stop secure-uki-confirm; systemctl reset-failed secure-uki-confirm")
    assert "VM_PCR_HANDOFF_AFTER_ENTER_INITRD" in console
    assert console.index("VM_PCR_HANDOFF_AFTER_ENTER_INITRD") < console.index("Finished Cryptography Setup for encrypted")


def require_recovery(closure):
    decision = {}

    def decide(_last_try):
        console = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", machine.get_console_log())
        if re.search(r"Please enter passphrase for disk[^\r\n]*\bencrypted\b", console):
            decision["mode"] = "recovery"
        elif "Reached target Multi-User System" in console:
            decision["mode"] = "unattended"
        elif "Starting password query on /dev/ttyS0" in console and not decision.get("flushed"):
            # The driver captures newline-terminated lines only. An empty,
            # unauthenticating attempt flushes a pending prompt; NEVER send the
            # recovery secret until the actual selected-mapper prompt is seen.
            machine.send_console("\n")
            decision["flushed"] = True
        return "mode" in decision

    driver_retry(decide, 90)
    assert decision["mode"] == "recovery", "unapproved policy signature automatically unlocked"
    root_recovery(machine)  # Observe prompt BEFORE sending independent synthetic secret.
    machine.succeed("test $(readlink -f /run/booted-system) = " + closure)
    machine.succeed("systemctl stop secure-uki-confirm; systemctl reset-failed secure-uki-confirm")
    print("Policy refused unattended unlock; independent manual recovery succeeded")


def enroll_live():
    signature = "/run/vm-enrollment-only.json"
    machine.succeed("umask 077; " + tools["measure"] + " sign --current --phase=: --bank=sha256 --private-key=" + policy_dir + "/private.pem --public-key=" + policy_dir + "/public.pem > " + signature)
    try:
        machine.succeed("PASSWORD=vm-recovery-only systemd-cryptenroll /dev/vda2 --tpm2-device=auto --tpm2-pcrlock= --tpm2-with-pin=no --tpm2-pcrs=7:sha256+12:sha256 --tpm2-public-key-pcrs=11 --tpm2-public-key=" + policy_dir + "/public.pem --tpm2-signature=" + signature)
    finally:
        machine.succeed("rm -f " + signature)
    machine.succeed("test ! -e " + signature)


def token_state():
    state = json.loads(machine.succeed("cryptsetup luksDump --dump-json-metadata /dev/vda2"))
    for token in state["tokens"].values():
        assert token["type"] == "systemd-tpm2"
        assert token["tpm2-pcr-bank"] == "sha256" and token["tpm2-pcrs"] == [7, 12]
        assert token["tpm2_pubkey_pcrs"] == [11]
        assert not token.get("tpm2-pin", False) and not token.get("tpm2_pcrlock", False)
    return state


# Initrd-only authorization must NOT satisfy the late-userspace enrollment safety
# check. The temporary live-state signature is never embedded/copied to ESP/store.
a_image = "/boot/EFI/Linux/" + current_manifest()["default"]
sections = json.loads(guest_command(machine, [tools["ukify"], "--json=short", "inspect", a_image]))
payload = sections[".pcrsig"]["text"]
guest_command(machine, ["python3", "-c", "import pathlib,sys; pathlib.Path('/run/initrd-only.json').write_text(sys.argv[1])", payload])
machine.fail("PASSWORD=vm-recovery-only systemd-cryptenroll /dev/vda2 --tpm2-device=auto --tpm2-pcrlock= --tpm2-with-pin=no --tpm2-pcrs=7:sha256+12:sha256 --tpm2-public-key-pcrs=11 --tpm2-public-key=" + policy_dir + "/public.pem --tpm2-signature=/run/initrd-only.json")
machine.succeed("rm /run/initrd-only.json")
assert not token_state()["tokens"]
pcr12_normal = machine.succeed("tpm2_pcrread sha256:12")
machine.succeed("cp " + a_image + " /persist/pcr-archive/old.efi")
enroll_live()
old_header = token_state()
assert len(old_header["tokens"]) == 1
old_token = next(iter(old_header["tokens"].values()))
old_slot = old_token["keyslots"][0]
# Assert actual emulator SRK, never accept a silently selected RSA parent.
srk = machine.succeed("tpm2_readpublic -c 0x81000001")
assert re.search(r"type:\s*\n\s*value: ecc", srk), "SRK is not ECC; abort rather than accept RSA fallback"
machine.succeed("tpm2_testparms ecc256:aes128cfb")
machine.fail("systemctl is-active systemd-pcrlock.service")
approved_selection()
cold_restart(machine)
auto_root(A_CLOSURE)
assert machine.succeed("tpm2_pcrread sha256:12") == pcr12_normal
machine.succeed("test -s /run/vm-initrd-evidence/tpm2-pcr-signature.json; test -s /run/vm-initrd-evidence/tpm2-pcr-public-key.pem")
assert json.loads(machine.succeed("cat /run/vm-initrd-evidence/tpm2-pcr-signature.json")) == json.loads(payload)

# Firmware-trusted image, only policy signature changed: causal isolation of
# signed-PCR authorization. Additional variants change measured data/public key.
for variant in ("wrong-signature", "missing-signature", "wrong-key", "missing-key", "cmdline", "initrd"):
    source = "/persist/pcr-archive/old.efi"
    machine.succeed("cp " + source + " /run/mutant.efi; sbattach --remove /run/mutant.efi")
    if variant == "wrong-signature":
        signature_json = json.loads(payload)
        if not POLICY_BYPASS_CONTROL:
            entry = signature_json["sha256"][0]
            bad = bytearray(base64.b64decode(entry["sig"]))
            bad[0] ^= 1
            entry["sig"] = base64.b64encode(bad).decode()
        guest_command(machine, ["python3", "-c", "import pathlib,sys; pathlib.Path('/run/section').write_text(sys.argv[1])", json.dumps(signature_json)])
        machine.succeed("objcopy --update-section .pcrsig=/run/section /run/mutant.efi")
    elif variant in ("missing-signature", "missing-key"):
        machine.succeed("objcopy --remove-section " + (".pcrsig" if variant == "missing-signature" else ".pcrpkey") + " /run/mutant.efi")
    elif variant == "wrong-key":
        make_test_keys(machine, "/run/vm-wrong-key")
        machine.succeed("objcopy --update-section .pcrpkey=/run/vm-wrong-key/public.pem /run/mutant.efi")
    elif variant == "cmdline":
        # objcopy keeps PE VirtualSize: appending text can lie beyond the
        # loaded section. Make an equal-length change to actually consumed data.
        cmdline = sections[".cmdline"]["text"].rstrip("\x00").replace("loglevel=7", "loglevel=6")
        assert cmdline != sections[".cmdline"]["text"].rstrip("\x00")
        guest_command(machine, ["python3", "-c", "import pathlib,sys; pathlib.Path('/run/section').write_bytes(sys.argv[1].encode()+bytes([0]))", cmdline])
        machine.succeed("objcopy --update-section .cmdline=/run/section /run/mutant.efi")
    else:
        machine.succeed("objcopy --update-section .initrd=" + C_CLOSURE + "/initrd /run/mutant.efi")
        # objcopy preserves PE VirtualSize/RVAs on section replacement. Repair
        # only appended metadata section layout; executable stub RVAs stay put.
        patch = "import pathlib,struct,sys; p=pathlib.Path('/run/mutant.efi'); d=bytearray(p.read_bytes()); pe=struct.unpack_from('<I',d,60)[0]; n=struct.unpack_from('<H',d,pe+6)[0]; opt=struct.unpack_from('<H',d,pe+20)[0]; headers=pe+24+opt; hs=[headers+40*i for i in range(n)]; s=next(h for h in hs if bytes(d[h:h+8]).rstrip(bytes([0]))==b'.initrd'); length=len(pathlib.Path(sys.argv[1]).read_bytes()); va=struct.unpack_from('<I',d,s+12)[0]; ends=[struct.unpack_from('<I',d,h+12)[0] for h in hs if struct.unpack_from('<I',d,h+12)[0]>va]; alignment=struct.unpack_from('<I',d,pe+24+32)[0]; delta=((max(0,va+length-min(ends))+alignment-1)//alignment)*alignment if ends else 0; later=[h for h in hs if struct.unpack_from('<I',d,h+12)[0]>va]; assert all(bytes(d[h:h+8]).rstrip(bytes([0])) in (b'.pcrsig',b'.pcrpkey',b'.uname',b'.cmdline',b'.osrel',b'.sbat',b'.dtb',b'.ucode',b'.splash') for h in later),'refuse relocating executable stub'; [struct.pack_into('<I',d,h+12,struct.unpack_from('<I',d,h+12)[0]+delta) for h in later]; struct.pack_into('<I',d,s+8,length); image_end=max(struct.unpack_from('<I',d,h+12)[0]+struct.unpack_from('<I',d,h+8)[0] for h in hs); struct.pack_into('<I',d,pe+24+56,((image_end+alignment-1)//alignment)*alignment); p.write_bytes(d)"
        guest_command(machine, ["python3", "-c", patch, C_CLOSURE + "/initrd"])
    machine.succeed("sbsign --key /var/lib/sbctl/keys/db/db.key --cert /var/lib/sbctl/keys/db/db.pem --output /boot/EFI/Linux/vm-negative.efi /run/mutant.efi")
    machine.succeed("sbverify --cert /var/lib/sbctl/keys/db/db.pem /boot/EFI/Linux/vm-negative.efi")
    select_probe_image(machine, "vm-negative.efi")
    cold_restart(machine)
    require_recovery(A_CLOSURE)
    assert machine.succeed("bootctl --print-stub-path").strip().endswith("vm-negative.efi"), "negative silently fell back"
    if variant == "cmdline":
        machine.succeed("grep -F loglevel=6 /proc/cmdline")
    if variant == "initrd":
        assert "VM_CHANGED_INITRD" in machine.get_console_log(), "changed initrd was not executed"
    machine.succeed("bootctl status | grep -E 'Secure Boot: enabled'; rm /boot/EFI/Linux/vm-negative.efi")
    approved_selection()
    cold_restart(machine)
    auto_root(A_CLOSURE)
    print("UEFI-trusted " + variant + " denied; unmodified image restores unattended boot")

# Same image/key/signature: unapproved credential and signed addon independently
# alter PCR12. The addon has a trusted db signature, not an unsigned-file refusal.
base_name = current_manifest()["default"]
for extension in ("credential", "signed-addon"):
    extra = "/boot/EFI/Linux/" + base_name + ".extra.d"
    machine.succeed("mkdir -p " + extra)
    if extension == "credential":
        machine.succeed("printf vm-unapproved-credential > " + extra + "/vm.cred")
    else:
        guest_command(machine, [tools["ukify"], "build", "--cmdline=vm_unapproved_addon=1", "--output=/run/vm.addon.efi"])
        machine.succeed("sbsign --key /var/lib/sbctl/keys/db/db.key --cert /var/lib/sbctl/keys/db/db.pem --output " + extra + "/vm.addon.efi /run/vm.addon.efi")
        machine.succeed("sbverify --cert /var/lib/sbctl/keys/db/db.pem " + extra + "/vm.addon.efi")
    cold_restart(machine)
    require_recovery(A_CLOSURE)
    assert machine.succeed("tpm2_pcrread sha256:12") != pcr12_normal
    machine.succeed("rm -r " + extra)
    cold_restart(machine)
    auto_root(A_CLOSURE)
    assert machine.succeed("tpm2_pcrread sha256:12") == pcr12_normal
    print(extension + " changed PCR12 and blocked auto-unlock; cleanup restores original PCR12")

# VM ONLY authenticated removal of PK, not dbx/TPM clear or a physical operation.
# Same signed UKI runs with Secure Boot disabled, but literal PCR7 no longer fits.
pcr7_normal = machine.succeed("tpm2_pcrread sha256:7")
machine.succeed("efi-readvar -v PK -o /persist/pcr-archive/PK.esl")
# Linux marks firmware key variables immutable even for root. Remove ONLY the
# disposable VM PK inode flag, then submit its authenticated signed deletion.
machine.succeed("lsattr /sys/firmware/efi/efivars/PK-8be4df61-93ca-11d2-aa0d-00e098032b8c")
machine.succeed("chattr -i /sys/firmware/efi/efivars/PK-8be4df61-93ca-11d2-aa0d-00e098032b8c")
machine.succeed("efi-updatevar -d 0 -k /var/lib/sbctl/keys/PK/PK.key PK")
cold_restart(machine)
require_recovery(A_CLOSURE)
machine.succeed("bootctl status | grep -E 'Secure Boot: disabled'")
assert machine.succeed("tpm2_pcrread sha256:7") != pcr7_normal
# Build a self-authenticated PK update in Setup Mode: efi-updatevar's inline
# signing looks up existing PK and therefore cannot recreate a deleted PK.
# Preserve EXACT original signature list (including owner GUID); leave dbx,
# KEK and db untouched. Signature/authenticated update stays only in volatile /run.
machine.succeed("sign-efi-sig-list -k /var/lib/sbctl/keys/PK/PK.key -c /var/lib/sbctl/keys/PK/PK.pem PK /persist/pcr-archive/PK.esl /run/vm-PK.auth")
machine.succeed("efi-updatevar -f /run/vm-PK.auth PK; rm /run/vm-PK.auth")
cold_restart(machine)
auto_root(A_CLOSURE)
assert machine.succeed("tpm2_pcrread sha256:7") == pcr7_normal

# Routine update includes genuinely changed initrd content. Native publication
# and actual boot confirmation drive retention, not test-written manifest state.
for closure in (B_CLOSURE, C_CLOSURE):
    machine.succeed("NIXOS_INSTALL_BOOTLOADER=1 " + closure + "/bin/switch-to-configuration boot")
    cold_restart(machine)
    auto_root(closure)
    if closure == C_CLOSURE:
        assert "VM_CHANGED_INITRD" in machine.get_console_log()
    assert token_state()["tokens"] == old_header["tokens"], "routine update re-enrolled"
    assert current_manifest()["known_good"] == current_manifest()["default"]
# Boot the retained B without enrollment; restore confirmed C afterward.
retained = next(name for name, info in current_manifest()["images"].items() if info["closure"] == B_CLOSURE)
select_probe_image(machine, retained)
cold_restart(machine)
auto_root(B_CLOSURE)
machine.succeed("NIXOS_INSTALL_BOOTLOADER=1 " + C_CLOSURE + "/bin/switch-to-configuration boot")
cold_restart(machine)
auto_root(C_CLOSURE)
state = current_manifest()
assert all(info["closure"] != A_CLOSURE for info in state["images"].values())
machine.succeed("test ! -e " + a_image)
# Retention cleanup is NOT revocation: archived authorization still unlocks.
machine.succeed("cp /persist/pcr-archive/old.efi /boot/EFI/Linux/vm-archived.efi")
select_probe_image(machine, "vm-archived.efi")
cold_restart(machine)
auto_root(A_CLOSURE, managed=False)
assert token_state()["tokens"] == old_header["tokens"]
machine.succeed("rm /boot/EFI/Linux/vm-archived.efi")
approved_selection()
cold_restart(machine)
auto_root(C_CLOSURE)
print("Native update/retained image unlock without enrollment; pruned archive still authorizes under old key")

# Deliberate VM-only PCR-key rotation: retain old recovery slot, publish only
# current C/new-key image first, manual recovery proves old token cannot accept it.
machine.succeed("install -d -m 0700 /persist/vm-old-pcr-key; cp -a " + policy_dir + "/. /persist/vm-old-pcr-key/")
machine.succeed("openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out " + policy_dir + "/private.pem; chmod 600 " + policy_dir + "/private.pem; openssl pkey -in " + policy_dir + "/private.pem -pubout -out " + policy_dir + "/public.pem")
machine.succeed("NIXOS_INSTALL_BOOTLOADER=1 " + C_CLOSURE + "/bin/switch-to-configuration boot")
cold_restart(machine)
require_recovery(C_CLOSURE)
machine.succeed("systemctl start secure-uki-confirm")
machine.wait_until_succeeds("test $(systemctl show secure-uki-confirm -p SubState --value) = exited")
enroll_live()
overlap = token_state()
assert len(overlap["tokens"]) == 2, "replacement must be validated before retiring old token"
assert all(overlap["keyslots"].get(key) == value for key, value in header["keyslots"].items()), "independent recovery slot changed"
# Validate replacement on actual cold boot before deleting anything.
cold_restart(machine)
auto_root(C_CLOSURE)
machine.succeed("PASSWORD=vm-recovery-only systemd-cryptenroll --wipe-slot=" + old_slot + " /dev/vda2")
rotated = token_state()
assert len(rotated["tokens"]) == 1
assert next(iter(rotated["tokens"].values()))["tpm2_pubkey"] != old_token["tpm2_pubkey"]
assert all(rotated["keyslots"].get(key) == value for key, value in header["keyslots"].items())
# Authorize only retained B/C under new key; old A was deliberately NOT signed.
machine.succeed("NIXOS_INSTALL_BOOTLOADER=1 " + B_CLOSURE + "/bin/switch-to-configuration boot")
cold_restart(machine)
auto_root(B_CLOSURE)
retained_new = next(name for name, info in current_manifest()["images"].items() if info["closure"] == C_CLOSURE)
select_probe_image(machine, retained_new)
cold_restart(machine)
auto_root(C_CLOSURE)
machine.succeed("cp /persist/pcr-archive/old.efi /boot/EFI/Linux/vm-archived.efi; sbverify --cert /var/lib/sbctl/keys/db/db.pem /boot/EFI/Linux/vm-archived.efi")
select_probe_image(machine, "vm-archived.efi")
cold_restart(machine)
require_recovery(A_CLOSURE)
assert token_state()["tokens"] == rotated["tokens"]
machine.succeed("rm /boot/EFI/Linux/vm-archived.efi")
approved_selection()
cold_restart(machine)
auto_root(B_CLOSURE)
# Independent passphrase still actually validates after old TPM slot retirement.
machine.succeed("printf vm-recovery-only | cryptsetup open --test-passphrase --key-file=- /dev/vda2")
assert all(token_state()["keyslots"].get(key) == value for key, value in header["keyslots"].items())
print("New key and replacement token unlock retained B/C; old archive refused after old token retirement; recovery survives")
