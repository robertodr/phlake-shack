{
  imports =
    let
      dir = builtins.readDir ./.;
      subdirs = builtins.filter (name: dir.${name} == "directory") (builtins.attrNames dir);
    in
    map (name: ./. + "/${name}") subdirs;
}
