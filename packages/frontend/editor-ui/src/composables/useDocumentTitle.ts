import { useSettingsStore } from '@/stores/settings.store';

const DEFAULT_TITLE = 'Workflow Automation';

export function useDocumentTitle() {
	const settingsStore = useSettingsStore();
	const suffix = 'Flow';

	const set = (title: string) => {
		const sections = [title || DEFAULT_TITLE, suffix];
		document.title = sections.join(' - ');
	};

	const reset = () => {
		set('');
	};

	return { set, reset };
}
