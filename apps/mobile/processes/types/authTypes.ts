import { Session, User } from '@supabase/supabase-js';

export type { Session, User };

export interface LoginResponse {
  session: Session;
  user: User;
}

export interface SignupResponse {
  session: Session | null;
  user: User;
}
