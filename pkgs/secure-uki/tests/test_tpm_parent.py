"""Offline parent contract; real swtpm persistence/identity checks have a VM test."""
import importlib
import struct
import unittest


def ecc_public(*, x=None, y=None, attrs=0x30472, name=0x0b, policy=b'', bits=128, mode=0x43, curve=3):
    # Independently specified NIST P256 generator, not production coordinates.
    gx=0x6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296
    gy=0x4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5
    x=gx.to_bytes(32,'big') if x is None else x
    y=gy.to_bytes(32,'big') if y is None else y
    raw=struct.pack('>HHIH',0x23,name,attrs,len(policy))+policy
    raw+=struct.pack('>HHHHHH',6,bits,mode,0x10,curve,0x10)
    raw+=struct.pack('>H',len(x))+x+struct.pack('>H',len(y))+y
    return struct.pack('>H',len(raw))+raw


class ParentContractTests(unittest.TestCase):
    def api(self,name):
        try: module=importlib.import_module('secure_uki.tpm_parent')
        except ModuleNotFoundError: module=None
        function=getattr(module,name,None)
        self.assertTrue(callable(function),'missing explicit-parent validation API')
        return function

    def test_default_zero_transient_platform_and_noninteger_selectors_refuse(self):
        validate=self.api('validate_parent_handle')
        for handle in (0,0x81000000,0x81000001,0x80000000,0x81800000,0x81ffffff,0x82000000,True,'0x81000042',None):
            with self.subTest(handle=handle),self.assertRaises(ValueError): validate(handle)

    def test_unused_owner_nondefault_selectors_are_validated_not_selected(self):
        validate=self.api('validate_parent_handle')
        # Synthetic boundaries ONLY, never a physical slot recommendation.
        self.assertEqual(validate(0x81000002),0x81000002)
        self.assertEqual(validate(0x817fffff),0x817fffff)

    def test_exact_ecc_parent_returns_nonunique_eligibility_only(self):
        validate=self.api('validate_parent')
        self.assertEqual(validate(ecc_public()),{'type':'ECC','curve':'P256','name_algorithm':'sha256','exact_template':True})

    def test_other_ecc_identity_with_identical_template_is_not_receipt_parent(self):
        validate=self.api('validate_parent')
        p=0xffffffff00000001000000000000000000000000ffffffffffffffffffffffff
        gy=0x4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5
        other=ecc_public(y=(p-gy).to_bytes(32,'big'))
        self.assertEqual(validate(other)['type'],'ECC')
        with self.assertRaises(ValueError): validate(other,expected_public=ecc_public())

    def test_rsa_unknown_truncated_oversized_and_trailing_public_refuse(self):
        validate=self.api('validate_parent'); good=ecc_public()
        rsa=bytearray(good); rsa[2:4]=b'\x00\x01'
        unknown=bytearray(good); unknown[2:4]=b'\xff\xff'
        for raw in (bytes(rsa),bytes(unknown),good[:-1],good+b'\0',b'\0'*4097,b'',None,'public'):
            with self.subTest(length=len(raw) if isinstance(raw,(bytes,str)) else None),self.assertRaises(ValueError): validate(raw)

    def test_wrong_template_or_invalid_p256_point_refuses(self):
        validate=self.api('validate_parent')
        for raw in (ecc_public(attrs=0x30072),ecc_public(name=0x0c),ecc_public(policy=b'\0'*32),
                    ecc_public(bits=256),ecc_public(mode=0x40),ecc_public(curve=4),
                    ecc_public(x=b''),ecc_public(x=b'\0'*32,y=b'\0'*32),ecc_public(x=b'\xff'*32),ecc_public(y=b'\1'*32)):
            with self.subTest(raw_length=len(raw)),self.assertRaises(ValueError): validate(raw)

    def test_persistent_or_foreign_context_cannot_be_passed_to_evictcontrol(self):
        validate=self.api('validate_transient_context')
        for hierarchy,handle in ((0x40000001,0x81000042),(0x4000000b,0x80000000),(0x40000001,0x02000000)):
            raw=struct.pack('>IIIIQH',0xbadcc0de,1,hierarchy,handle,1,3)+b'abc'
            with self.subTest(handle=handle),self.assertRaises(ValueError): validate(raw)

    def test_only_bound_owner_transient_context_format_is_accepted(self):
        validate=self.api('validate_transient_context')
        raw=struct.pack('>IIIIQH',0xbadcc0de,1,0x40000001,0x80000000,1,3)+b'abc'
        self.assertIsNone(validate(raw))
        for bad in (raw[:-1],raw+b'\0',b'\0'*len(raw),raw[:4]+struct.pack('>I',2)+raw[8:]):
            with self.assertRaises(ValueError): validate(bad)
