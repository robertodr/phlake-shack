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
      # hypothesis
      {id = "bjfhmglciegochdpefhhlphglcehbmek";}
      # joplin web clipper
      {id = "alofnhikmmkdbbbgpnglcpdollgjjfek";}
      # paperpile
      {id = "bomfdkbfpdhijjbeoicnfhjbdhncfhig";}
      # unpaywall
      {id = "iplffkdpngmdjhlpjmppncnlhomiipha";}
    ];
  };
}
