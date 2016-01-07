import Colors from '../colors';
import ColorManipulator from '../../utils/color-manipulator';
import Spacing from '../spacing';
import zIndex from '../zIndex';

export default {
  spacing: Spacing,
  fontFamily: 'Roboto, sans-serif',
  zIndex: zIndex,
  palette: {
    primary1Color: Colors.amber700,
    primary2Color: Colors.amber700,
    primary3Color: Colors.blueGrey500,
    accent1Color: Colors.blueGrey500,
    accent2Color: Colors.blueGrey500,
    accent3Color: Colors.amber700,
    textColor: Colors.darkBlack,
    alternateTextColor: Colors.grey50,
    canvasColor: Colors.blueGrey900,
    borderColor: ColorManipulator.fade(Colors.fullWhite, 0.3),
    disabledColor: ColorManipulator.fade(Colors.fullWhite, 0.3),
    pickerHeaderColor: ColorManipulator.fade(Colors.fullWhite, 0.12),
    clockCircleColor: ColorManipulator.fade(Colors.fullWhite, 0.12),
  },
};
