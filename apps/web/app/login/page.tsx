import { redirect } from 'next/navigation';
import { loginAction } from '@/app/actions';
import { getCurrentUser } from '@/lib/session';

const errorMessages: Record<string, string> = {
  invalid_credentials: 'The email or password did not match a Core API user.',
  missing_credentials: 'Enter both email and password to continue.',
};

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const [user, params] = await Promise.all([getCurrentUser(), searchParams]);

  if (user) {
    redirect('/app');
  }

  const errorMessage = params.error ? errorMessages[params.error] : undefined;

  return (
    <main className="page-shell">
      <section className="auth-panel" aria-labelledby="login-title">
        <p className="eyebrow">Matome Web</p>
        <h1 id="login-title">Sign in to your recordings</h1>
        <p className="lede">Authenticate against the Matome Core API. Tokens are stored in HTTP-only cookies.</p>
        {errorMessage ? <p className="alert">{errorMessage}</p> : null}
        <form action={loginAction} className="form-stack">
          <label className="field">
            <span>Email</span>
            <input autoComplete="email" name="email" required type="email" />
          </label>
          <label className="field">
            <span>Password</span>
            <input autoComplete="current-password" name="password" required type="password" />
          </label>
          <button className="button" type="submit">Sign in</button>
        </form>
      </section>
    </main>
  );
}
