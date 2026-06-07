import { getServerT } from '@/lib/i18n/server';
import { SpacesManager } from '../SpacesManager';
import { loadReviewData } from '../review-data';

export default async function SpacesPage() {
  const [{ t }, data] = await Promise.all([getServerT(), loadReviewData()]);

  const spaceCounts = data.spaces.reduce<Record<number, number>>((acc, space) => {
    acc[space.id] = data.recordings.filter((recording) => recording.workspace_id === space.id).length;
    return acc;
  }, {});

  return (
    <section className="review-main" aria-labelledby="spaces-title">
      <header className="hero-row">
        <div>
          <p className="eyebrow">{t('spaces.title')}</p>
          <h1 id="spaces-title">{t('spaces.title')}</h1>
          <p className="lede">{t('web.dashLede')}</p>
        </div>
      </header>

      <SpacesManager spaces={data.spaces} counts={spaceCounts} inboxCount={data.inboxCount} />
    </section>
  );
}
