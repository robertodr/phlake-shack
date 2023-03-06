{
  programs.brave = {
    enable = true;

    commandLineArgs = [
      "--enable-features=UseOzonePlatform,WaylandWindowDecorations"
      "--ozone-platform=wayland"
    ];

    extensions = [
      # 1password
      {id = "aeblfdkhhhdcdjpifhhbdiojplfjncoa";}
      # C/C++ Search Extension
      {id = "ifpcmhciihicaljnhgobnhoehoabidhd";}
      # joplin web clipper
      {id = "alofnhikmmkdbbbgpnglcpdollgjjfek";}
      # nordpvn
      {id = "fjoaledfpmneenckfbpdfhkmimnjocfa";}
      # paperpile
      {id = "bomfdkbfpdhijjbeoicnfhjbdhncfhig";}
    ];
  };
}
