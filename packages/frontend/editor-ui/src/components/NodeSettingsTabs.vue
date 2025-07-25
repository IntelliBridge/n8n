<script setup lang="ts">
import type { ITab } from '@/Interface';
import { COMMUNITY_NODES_INSTALLATION_DOCS_URL } from '@/constants';
import { useNDVStore } from '@/stores/ndv.store';
import { useWorkflowsStore } from '@/stores/workflows.store';
import type { INodeTypeDescription } from 'n8n-workflow';
import { NodeConnectionTypes } from 'n8n-workflow';
import { computed } from 'vue';

import { useExternalHooks } from '@/composables/useExternalHooks';
import { useI18n } from '@/composables/useI18n';
import { useTelemetry } from '@/composables/useTelemetry';
import { isCommunityPackageName } from '@/utils/nodeTypesUtils';

type Tab = 'settings' | 'params';
type Props = {
	modelValue?: Tab;
	nodeType?: INodeTypeDescription | null;
	pushRef?: string;
};

const props = withDefaults(defineProps<Props>(), {
	modelValue: 'params',
	nodeType: undefined,
	pushRef: '',
});
const emit = defineEmits<{
	'update:model-value': [tab: Tab];
}>();

const externalHooks = useExternalHooks();
const ndvStore = useNDVStore();
const workflowsStore = useWorkflowsStore();
const i18n = useI18n();
const telemetry = useTelemetry();

const activeNode = computed(() => ndvStore.activeNode);

const isCommunityNode = computed(() => {
	const nodeType = props.nodeType;
	if (nodeType) {
		return isCommunityPackageName(nodeType.name);
	}
	return false;
});

const packageName = computed(() => props.nodeType?.name.split('.')[0] ?? '');

const documentationUrl = computed(() => {
	return false;
});

const options = computed<ITab[]>(() => {
	const options: ITab[] = [
		{
			label: i18n.baseText('nodeSettings.parameters'),
			value: 'params',
		},
		{
			label: i18n.baseText('nodeSettings.settings'),
			value: 'settings',
		},
	];

	if (isCommunityNode.value) {
		options.push({
			icon: 'cube',
			value: 'communityNode',
			align: 'right',
			tooltip: i18n.baseText('generic.communityNode.tooltip', {
				interpolate: {
					docUrl: COMMUNITY_NODES_INSTALLATION_DOCS_URL,
					packageName: packageName.value,
				},
			}),
		});
	}

	if (documentationUrl.value) {
		options.push({
			label: i18n.baseText('nodeSettings.docs'),
			value: 'docs',
			href: documentationUrl.value,
			align: 'right',
		});
	}

	return options;
});

function onTabSelect(tab: string) {
	if (tab === 'docs' && props.nodeType) {
		void externalHooks.run('dataDisplay.onDocumentationUrlClick', {
			nodeType: props.nodeType,
			documentationUrl: documentationUrl.value,
		});

		telemetry.track('User clicked ndv link', {
			node_type: activeNode.value?.type,
			workflow_id: workflowsStore.workflowId,
			push_ref: props.pushRef,
			pane: NodeConnectionTypes.Main,
			type: 'docs',
		});
	}

	if (tab === 'settings' && props.nodeType) {
		telemetry.track('User viewed node settings', {
			node_type: props.nodeType.name,
			workflow_id: workflowsStore.workflowId,
		});
	}

	if (tab === 'settings' || tab === 'params') {
		emit('update:model-value', tab);
	}
}

function onTooltipClick(tab: string, event: MouseEvent) {
	if (tab === 'communityNode' && (event.target as Element).localName === 'a') {
		telemetry.track('user clicked cnr docs link', { source: 'node details view' });
	}
}
</script>

<template>
	<N8nTabs
		:options="options"
		:model-value="modelValue"
		@update:model-value="onTabSelect"
		@tooltip-click="onTooltipClick"
	/>
</template>

<style lang="scss">
#communityNode > div {
	cursor: auto;
	padding-right: 0;
	padding-left: 0;

	&:hover {
		color: unset;
	}
}
</style>
