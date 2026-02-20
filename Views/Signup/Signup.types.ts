export type SignupProps = {
  name: string;
  email: string;
  password: string;
  confirmPassword: string;
  setName: (name: string) => void;
  setEmail: (email: string) => void;
  setPassword: (password: string) => void;
  setConfirmPassword: (confirmPassword: string) => void;
  onSignupPress: () => void;
  onLoginPress: () => void;
  isLoading: boolean;
};
