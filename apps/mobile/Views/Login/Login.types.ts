export type LoginProps = {
    email: string;
    password: string;
    setEmail: (email: string) => void;
    setPassword: (password: string) => void;
    onLoginPress: () => void;
    isLoading: boolean;
  }