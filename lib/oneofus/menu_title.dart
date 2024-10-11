import 'package:flutter/material.dart';

const Color kYellow = Color.fromARGB(255, 255, 230, 0);

class MenuTitle extends StatelessWidget {
  static const List<Color> colors = [Colors.red, Colors.green, kYellow, Colors.brown];

  final List<String> title;

  const MenuTitle(
    this.title, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    List<Text> texts = <Text>[];
    int i = 0;
    for (String t in title) {
      texts.add(Text(
        t,
        style: TextStyle(color: colors[i++ % colors.length]),
      ));
    }
    return SubmenuButton(
        // style: ButtonStyle(
        //     textStyle: WidgetStateProperty.all<TextStyle>(
        //         const TextStyle(fontWeight: FontWeight.normal))),
        menuChildren: const <Widget>[],
        child: Row(
          children: [
            const Spacer(),
            ...texts,
          ],
        ));

    // final double size = MediaQuery.of(context).size.width * 0.3;
    // return SizedBox(
    //     width: size,
    //     child: SubmenuButton(
    //         // style: ButtonStyle(
    //         //     textStyle: WidgetStateProperty.all<TextStyle>(
    //         //         const TextStyle(fontWeight: FontWeight.normal))),
    //         menuChildren: const <Widget>[],
    //         child: Row(
    //           children: [
    //             const Spacer(),
    //             ...texts,
    //           ],
    //         )));
  }
}
