import * as eva from '@eva-design/eva';
import { ThemeType } from '@ui-kitten/components';
import { darkEvaTheme, lightEvaTheme } from '@matome/ui';

export const lightTheme: ThemeType = {
  ...eva.light,
  ...lightEvaTheme,
};

export const darkTheme: ThemeType = {
  ...eva.dark,
  ...darkEvaTheme,
};
