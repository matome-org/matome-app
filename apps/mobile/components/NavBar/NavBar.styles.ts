import { StyleSheet } from 'react-native';

export const styles = StyleSheet.create({
  tabBar: {
    flexDirection: 'row',
    height: 84,
    paddingBottom: 20,
    borderTopWidth: 1,
    alignItems: 'center',
    paddingHorizontal: 8,
  },
  tabItem: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 3,
  },
  tabLabel: {
    fontSize: 10,
    fontWeight: '500',
  },
  micWrapper: {
    width: 64,
    alignItems: 'center',
    justifyContent: 'center',
  },
  micButton: {
    width: 58,
    height: 58,
    borderRadius: 29,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: -20,
    borderWidth: 3,
    shadowColor: '#E1B346',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.45,
    shadowRadius: 8,
    elevation: 6,
  },
  micIcon: {
    width: 26,
    height: 26,
  },
  tabIcon: {
    width: 24,
    height: 24,
  },
});
