import { redirect } from 'next/navigation';
import { loginAction } from '@/app/actions';
import { getCurrentUser } from '@/lib/session';
import { getServerT } from '@/lib/i18n/server';

const errorKeys: Record<string, string> = {
  invalid_credentials: 'web.invalidCredentials',
  missing_credentials: 'web.missingCredentials',
};

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const [user, params, { t }] = await Promise.all([
    getCurrentUser(),
    searchParams,
    getServerT(),
  ]);

  if (user) {
    redirect('/app');
  }

  const errorMessage = params.error && errorKeys[params.error] ? t(errorKeys[params.error]) : undefined;

  return (
    <main className="page-shell">
      <section className="auth-panel" aria-labelledby="login-title">
        <p className="eyebrow">{t('web.eyebrow')}</p>
        <h1 id="login-title">{t('web.signInTitle')}</h1>
        <p className="lede">{t('web.signInLede')}</p>
        {errorMessage ? <p className="alert">{errorMessage}</p> : null}
        <form action={loginAction} className="form-stack">
          <label className="field">
            <span>{t('auth.email')}</span>
            <input autoComplete="email" name="email" required type="email" />
          </label>
          <label className="field">
            <span>{t('auth.password')}</span>
            <input autoComplete="current-password" name="password" required type="password" />
          </label>
          <button className="button" type="submit">{t('welcome.signIn')}</button>
        </form>
      </section>
    </main>
  );
}
