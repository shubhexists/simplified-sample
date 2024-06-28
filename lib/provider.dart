import 'package:flutter/material.dart';
class BoxColorProvider with ChangeNotifier {
  bool _boxcolor = false;

  bool get boxcolor => _boxcolor;

  void toggleBoxColor() {
    _boxcolor = !_boxcolor;
    notifyListeners();
  }
}
