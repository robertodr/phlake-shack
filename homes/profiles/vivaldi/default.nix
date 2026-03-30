{ ... }:
{
  programs.vivaldi = {
    enable = true;

    extensions = [
      # free
      # C/C++ Search Extension
      { id = "ifpcmhciihicaljnhgobnhoehoabidhd"; }
      # darkreader
      { id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; }
      # decentraleyes
      { id = "ldpochfccnmeaoehlefnkdbjgbjhdcdd"; }
      # libkey-nomad
      { id = "lkoeejijapdihgbegpljiehpnlkadljb"; }
      # privacy badger
      { id = "pkehgijcmpdhfbdbbnkijodmdjhbjlg"; }
      # rust search extension
      { id = "ennpfpdlaclocpomkiablnmbppdnlhoh"; }
      # unpaywall
      { id = "iplffkdpngmdjhlpjmppncnlhomiipha"; }

      # unfree
      # 1password
      { id = "aeblfdkhhhdcdjpifhhbdiojplfjncoa"; }
      # notion web clipper
      { id = "knheggckgoiihginacbkhaalnibhilkk"; }
      # paperpile
      { id = "bomfdkbfpdhijjbeoicnfhjbdhncfhig"; }
    ];
  };
}
