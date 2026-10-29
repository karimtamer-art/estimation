import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// One face a seat can wear. The seat stores [id], never the file.
class Avatar {
  final int id;
  final String name;
  final String nameAr;
  final String asset;
  const Avatar(this.id, this.name, this.nameAr, this.asset);

  String label(bool arabic) => arabic ? nameAr : name;
}

/// The ten flat faces, in id order. Each is drawn on an 80×80 board with
/// its own square background.
const List<Avatar> kAvatars = [
  Avatar(0, 'Fox', 'ثعلب', 'assets/avatars/avatar_0_fox.svg'),
  Avatar(1, 'Owl', 'بومة', 'assets/avatars/avatar_1_owl.svg'),
  Avatar(2, 'Bear', 'دب', 'assets/avatars/avatar_2_bear.svg'),
  Avatar(3, 'Frog', 'ضفدع', 'assets/avatars/avatar_3_frog.svg'),
  Avatar(4, 'Pharaoh Cat', 'قطة فرعونية',
      'assets/avatars/avatar_4_pharaoh_cat.svg'),
  Avatar(5, 'Camel', 'جمل', 'assets/avatars/avatar_5_camel.svg'),
  Avatar(6, 'Horus Falcon', 'صقر حورس',
      'assets/avatars/avatar_6_horus_falcon.svg'),
  Avatar(7, 'Scarab', 'جعران', 'assets/avatars/avatar_7_scarab.svg'),
  Avatar(8, 'Baladi Dog', 'كلب بلدي', 'assets/avatars/avatar_8_baladi_dog.svg'),
  Avatar(9, 'Towel', 'فوطة', 'assets/avatars/avatar_9_towel.svg'),
];

class AvatarFace extends StatelessWidget {
  final int index;
  final double size;
  const AvatarFace({super.key, required this.index, required this.size});

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        kAvatars[index % kAvatars.length].asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
}
