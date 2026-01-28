import { Layout, Text } from '@ui-kitten/components';
import { StyleSheet } from 'react-native';

const Explore = () => {
  return (
    <Layout style={styles.container}>
      <Text>Explore</Text>
    </Layout>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
});

export default Explore;