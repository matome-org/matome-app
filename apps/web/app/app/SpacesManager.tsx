'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { useTranslation } from 'react-i18next';
import type { Space } from '@matome/api-client';
import { createSpaceAction, deleteSpaceAction, updateSpaceAction } from '@/app/actions';

export function SpacesManager({
  spaces,
  counts,
  inboxCount,
}: {
  spaces: Space[];
  counts: Record<number, number>;
  inboxCount: number;
}) {
  const router = useRouter();
  const { t } = useTranslation();
  const [isPending, startTransition] = useTransition();

  const [newName, setNewName] = useState('');
  const [editingId, setEditingId] = useState<number | null>(null);
  const [editingName, setEditingName] = useState('');
  const [error, setError] = useState<string | null>(null);

  const refresh = () => startTransition(() => router.refresh());

  const create = async () => {
    if (!newName.trim()) {
      return;
    }
    try {
      setError(null);
      await createSpaceAction({ name: newName });
      setNewName('');
      refresh();
    } catch {
      setError(t('toast.notesFailed'));
    }
  };

  const rename = async (id: number) => {
    try {
      setError(null);
      await updateSpaceAction(id, { name: editingName });
      setEditingId(null);
      refresh();
    } catch {
      setError(t('toast.notesFailed'));
    }
  };

  const remove = async (id: number, name: string) => {
    if (!window.confirm(`${t('common.cancel')}? — ${name}`)) {
      return;
    }
    try {
      setError(null);
      await deleteSpaceAction(id);
      refresh();
    } catch {
      setError(t('toast.notesFailed'));
    }
  };

  return (
    <article className="surface-card" id="spaces" aria-labelledby="spaces-title">
      <div className="section-heading">
        <div>
          <p className="eyebrow">{t('spaces.title')}</p>
          <h2 id="spaces-title">{t('spaces.title')}</h2>
        </div>
        <span>{spaces.length}</span>
      </div>

      <div className="space-create">
        <input
          value={newName}
          onChange={(event) => setNewName(event.target.value)}
          placeholder={t('spaces.emptyHint')}
          onKeyDown={(event) => {
            if (event.key === 'Enter') {
              void create();
            }
          }}
        />
        <button className="button" type="button" onClick={() => void create()} disabled={isPending || !newName.trim()}>
          +
        </button>
      </div>

      <div className="space-list">
        <div className="space-row">
          <div>
            <strong>{t('web.inboxLabel')}</strong>
            <p>{t('web.unassigned')}</p>
          </div>
          <span>{inboxCount}</span>
        </div>

        {spaces.map((space) => (
          <div className="space-row" key={space.id}>
            {editingId === space.id ? (
              <div className="space-edit">
                <input value={editingName} onChange={(event) => setEditingName(event.target.value)} autoFocus />
                <button className="button" type="button" onClick={() => void rename(space.id)}>
                  {t('common.save')}
                </button>
                <button className="button ghost" type="button" onClick={() => setEditingId(null)}>
                  {t('common.cancel')}
                </button>
              </div>
            ) : (
              <>
                <div>
                  <strong>{space.name}</strong>
                  <p>{space.description || '—'}</p>
                </div>
                <div className="space-actions">
                  <span>{counts[space.id] ?? 0}</span>
                  <button
                    className="button ghost"
                    type="button"
                    onClick={() => {
                      setEditingId(space.id);
                      setEditingName(space.name);
                    }}
                    aria-label={t('details.edit')}
                  >
                    ✎
                  </button>
                  <button
                    className="button ghost"
                    type="button"
                    onClick={() => void remove(space.id, space.name)}
                    aria-label="delete"
                  >
                    🗑
                  </button>
                </div>
              </>
            )}
          </div>
        ))}
        {spaces.length === 0 ? <p className="empty-state">{t('spaces.empty')}</p> : null}
      </div>
      {error ? <small className="record-message">{error}</small> : null}
    </article>
  );
}
