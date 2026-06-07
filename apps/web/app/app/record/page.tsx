import { getServerT } from '@/lib/i18n/server';
import { RecordRecordingPanel } from '../RecordRecordingPanel';
import { UploadRecordingPanel } from '../UploadRecordingPanel';
import { loadReviewData } from '../review-data';

export default async function RecordPage() {
  const [{ t }, data] = await Promise.all([getServerT(), loadReviewData()]);

  return (
    <section className="review-main" aria-labelledby="record-page-title">
      <header className="hero-row">
        <div>
          <p className="eyebrow">{t('web.navRecord')}</p>
          <h1 id="record-page-title">{t('recording.ready')}</h1>
          <p className="lede">{t('recording.startHint')}</p>
        </div>
      </header>

      <section className="surface-grid two-column" id="capture">
        <RecordRecordingPanel />
        <UploadRecordingPanel spaces={data.spaces} />
      </section>
    </section>
  );
}
