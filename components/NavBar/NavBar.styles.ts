import { StyleSheet } from 'react-native';

export const styles = StyleSheet.create({
  tabBar: {
    flexDirection: 'row',
    height: 84,
    paddingBottom: 20,
    borderTopWidth: 1,
    justifyContent: 'space-around',
    alignItems: 'center',
    paddingHorizontal: 20,
  },
  tabItem: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 4,
  },
  tabLabel: {
    fontSize: 10,
    fontWeight: '500',
    marginTop: 4,
  },
  micButton: {
    width: 64,
    height: 64,
    borderRadius: 32,
    alignItems: 'center',
    justifyContent: 'center',
    marginHorizontal: 20,
    marginTop: -24, // Elevate the button above the tab bar
    borderWidth: 4,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
  },
  micIcon: {
    width: 28,
    height: 28,
  },
  tabIcon: {
    width: 24,
    height: 24,
  },
});
