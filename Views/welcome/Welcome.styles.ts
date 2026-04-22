import { StyleSheet } from 'react-native';

export const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  scroll: {
    paddingHorizontal: 28,
    flexGrow: 1,
  },
  wordmarkRow: {
    marginBottom: 48,
  },
  wordmarkJP: {
    fontSize: 22,
    fontWeight: '800',
    letterSpacing: -0.5,
  },
  wordmarkEN: {
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 2,
    marginTop: 2,
  },
  headlineBlock: {
    marginBottom: 40,
  },
  headline: {
    fontSize: 38,
    fontWeight: '800',
    letterSpacing: -1,
    lineHeight: 44,
  },
  headlineAccent: {
    fontSize: 38,
    fontWeight: '800',
    letterSpacing: -1,
    lineHeight: 44,
  },
  subheadline: {
    fontSize: 15,
    lineHeight: 22,
    marginTop: 14,
    maxWidth: 300,
  },
  featureList: {
    gap: 14,
    marginBottom: 8,
  },
  featureRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
  },
  featureIcon: {
    width: 44,
    height: 44,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
  },
  featureText: {
    flex: 1,
  },
  featureTitle: {
    fontSize: 14,
    fontWeight: '700',
  },
  featureSubtitle: {
    fontSize: 12,
    marginTop: 1,
    lineHeight: 17,
  },
  spacer: {
    flex: 1,
    minHeight: 32,
  },
  primaryBtn: {
    paddingVertical: 16,
    borderRadius: 14,
    alignItems: 'center',
    marginBottom: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.2,
    shadowRadius: 8,
    elevation: 4,
  },
  primaryBtnText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '700',
  },
  ghostBtn: {
    alignItems: 'center',
    paddingVertical: 8,
  },
  ghostBtnText: {
    fontSize: 13,
  },
  ghostBtnTextBold: {
    fontSize: 13,
    fontWeight: '700',
    textDecorationLine: 'underline',
  },
});
