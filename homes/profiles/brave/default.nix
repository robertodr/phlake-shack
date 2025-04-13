{
  programs.brave = {
    enable = true;

    # these are taken from: https://community.frame.work/t/videos-calls-on-framework-fans-heat-hot-temperatures/17585/17
    commandLineArgs = [
      "--disable-gpu-driver-bug-workarounds"
      "--use-gl=egl"
      "--ignore-gpu-blocklist"
      "--enable-gpu-rasterization"
      "--enable-zero-copy"
      "--enable-features=VaapiVideoDecoder,VaapiVideoEncoder,CanvasOopRasterization,UseOzonePlatform"
      "--disable-features=UseChromeOSDirectVideoDecoder"
      "--ozone-platform=wayland"
    ];

    extensions = [
      # 1password
      { id = "aeblfdkhhhdcdjpifhhbdiojplfjncoa"; }
      # C/C++ Search Extension
      { id = "ifpcmhciihicaljnhgobnhoehoabidhd"; }
      # joplin web clipper
      { id = "alofnhikmmkdbbbgpnglcpdollgjjfek"; }
      # nordpvn
      { id = "fjoaledfpmneenckfbpdfhkmimnjocfa"; }
      # notion web clipper
      { id = "knheggckgoiihginacbkhaalnibhilkk"; }
      # paperpile
      { id = "bomfdkbfpdhijjbeoicnfhjbdhncfhig"; }
    ];
  };
}
