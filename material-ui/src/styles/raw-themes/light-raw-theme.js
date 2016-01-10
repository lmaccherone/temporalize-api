import Colors from '../colors';
import ColorManipulator from '../../utils/color-manipulator';
import Spacing from '../spacing';
import zIndex from '../zIndex';

/*
 *  Light Theme is the default theme used in material-ui. It is guaranteed to
 *  have all theme variables needed for every component. Variables not defined
 *  in a custom theme will default to these values.
 */

export default {
  spacing: Spacing,
  fontFamily: 'Roboto, sans-serif',
  zIndex: zIndex,
  palette: {
    primary1Color: Colors.deepOrange700,
    primary2Color: Colors.deepOrange700,
    primary3Color: Colors.lightBlue50,
    accent1Color: Colors.lightBlue800,
    accent2Color: Colors.lightBlue800,
    accent3Color: Colors.lightBlue800,
    textColor: '#272727',
    alternateTextColor: Colors.grey50,
    canvasColor: Colors.grey50,
    borderColor: Colors.grey300,
    disabledColor: ColorManipulator.fade(Colors.darkBlack, 0.3),
    pickerHeaderColor: '#272727',
    clockCircleColor: '#272727',
  },
};
