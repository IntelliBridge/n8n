import { NPM_PACKAGE_DOCS_BASE_URL } from '../constants';
import { useNodeDocsUrl } from './useNodeDocsUrl';

import type { INodeTypeDescription } from 'n8n-workflow';
import { mock } from 'vitest-mock-extended';

describe('useNodeDocsUrl', () => {
	it('returns full documentationUrl if set', () => {
		const nodeType = mock<INodeTypeDescription>({
			name: 'n8n-nodes-base.set',
			documentationUrl: 'https://example.com/docs',
		});
		const { docsUrl } = useNodeDocsUrl({ nodeType });
		expect(docsUrl.value).toBe('https://example.com/docs');
	});

	// Flow: built-in nodes never link to upstream's docs site
	it('suppresses codex primaryDocumentation url for built-in nodes', () => {
		const nodeType = mock<INodeTypeDescription>({
			name: 'n8n-nodes-base.set',
			documentationUrl: '',
			codex: {
				resources: {
					primaryDocumentation: [{ url: 'https://docs.n8n.io/nodes/MyNode' }],
				},
			},
		});

		const { docsUrl } = useNodeDocsUrl({ nodeType });

		expect(docsUrl.value).toBe('');
	});

	it('returns community docs url for community-nodes', () => {
		const nodeType = mock<INodeTypeDescription>({
			name: 'n8n-nodes-custom.custom',
			documentationUrl: '',
		});
		const { docsUrl } = useNodeDocsUrl({ nodeType });

		expect(docsUrl.value).toBe(`${NPM_PACKAGE_DOCS_BASE_URL}n8n-nodes-custom`);
	});

	it('suppresses builtin docs root fallback', () => {
		const nodeType = mock<INodeTypeDescription>({
			name: 'n8n-nodes-base.set',
			documentationUrl: '',
		});
		const { docsUrl } = useNodeDocsUrl({ nodeType });

		expect(docsUrl.value).toBe('');
	});

	it('returns empty string if documentationUrl is null', () => {
		const nodeType = null;
		const { docsUrl } = useNodeDocsUrl({ nodeType });

		expect(docsUrl.value).toBe('');
	});
});
