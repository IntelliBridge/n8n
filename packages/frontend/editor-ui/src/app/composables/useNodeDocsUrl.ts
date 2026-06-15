import { type INodeTypeDescription, isCommunityPackageName } from 'n8n-workflow';
import { computed, toValue, type MaybeRefOrGetter } from 'vue';
import { NPM_PACKAGE_DOCS_BASE_URL } from '../constants';

export const useNodeDocsUrl = ({
	nodeType: nodeTypeRef,
}: { nodeType: MaybeRefOrGetter<INodeTypeDescription | null | undefined> }) => {
	const packageName = computed(() => toValue(nodeTypeRef)?.name.split('.')[0] ?? '');

	const isCommunityNode = computed(() => {
		const nodeType = toValue(nodeTypeRef);
		if (nodeType) {
			return isCommunityPackageName(nodeType.name);
		}
		return false;
	});

	const docsUrl = computed(() => {
		const nodeType = toValue(nodeTypeRef);
		if (!nodeType) {
			return '';
		}

		if (nodeType.documentationUrl?.startsWith('http')) {
			return nodeType.documentationUrl;
		}

		if (isCommunityNode.value) {
			return `${NPM_PACKAGE_DOCS_BASE_URL}${packageName.value}`;
		}

		// Flow: built-in nodes link to upstream's docs site (codex
		// primaryDocumentation / BUILTIN_NODES_DOCS_URL). Suppress those links
		// centrally instead of stripping the URLs from every node definition,
		// which is what the 1.90 fork did across 88 files. Render sites hide
		// the link when docsUrl is empty.
		return '';
	});

	return { docsUrl };
};
