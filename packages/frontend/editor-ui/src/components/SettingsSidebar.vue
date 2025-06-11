<script lang="ts" setup>
import { computed } from 'vue';
import { ABOUT_MODAL_KEY, VIEWS } from '@/constants';
import { useUserHelpers } from '@/composables/useUserHelpers';
import type { IMenuItem } from '@n8n/design-system';
import { useUIStore } from '@/stores/ui.store';
import { useSettingsStore } from '@/stores/settings.store';
import { useRootStore } from '@/stores/root.store';
import { hasPermission } from '@/utils/rbac/permissions';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from '@/composables/useI18n';

const emit = defineEmits<{
	return: [];
}>();

const router = useRouter();
const route = useRoute();
const i18n = useI18n();

const { canUserAccessRouteByName } = useUserHelpers(router, route);

const rootStore = useRootStore();
const settingsStore = useSettingsStore();
const uiStore = useUIStore();

const sidebarMenuItems = computed<IMenuItem[]>(() => {
	const menuItems: IMenuItem[] = [
		{
			id: 'settings-usage-and-plan',
			icon: 'chart-bar',
			label: i18n.baseText('settings.usageAndPlan.title'),
			position: 'top',
			available: canUserAccessRouteByName(VIEWS.USAGE),
			route: { to: { name: VIEWS.USAGE } },
		},
		{
			id: 'settings-personal',
			icon: 'user-circle',
			label: i18n.baseText('settings.personal'),
			position: 'top',
			available: canUserAccessRouteByName(VIEWS.PERSONAL_SETTINGS),
			route: { to: { name: VIEWS.PERSONAL_SETTINGS } },
		},
		{
			id: 'settings-users',
			icon: 'user-friends',
			label: i18n.baseText('settings.users'),
			position: 'top',
			available: canUserAccessRouteByName(VIEWS.USERS_SETTINGS),
			route: { to: { name: VIEWS.USERS_SETTINGS } },
		},
		{
			id: 'settings-workersview',
			icon: 'project-diagram',
			label: i18n.baseText('mainSidebar.workersView'),
			position: 'top',
			available:
				settingsStore.isQueueModeEnabled &&
				hasPermission(['rbac'], { rbac: { scope: 'workersView:manage' } }),
			route: { to: { name: VIEWS.WORKER_VIEW } },
		},
	];

	return menuItems;
});
</script>

<template>
	<div :class="$style.container">
		<n8n-menu :items="sidebarMenuItems">
			<template #header>
				<div :class="$style.returnButton" data-test-id="settings-back" @click="emit('return')">
					<i class="mr-xs">
						<font-awesome-icon icon="arrow-left" />
					</i>
					<n8n-heading size="large" :bold="true">{{ i18n.baseText('settings') }}</n8n-heading>
				</div>
			</template>
			<template #menuSuffix>
				<div :class="$style.versionContainer">
					<n8n-link size="small" @click="uiStore.openModal(ABOUT_MODAL_KEY)">
						{{ i18n.baseText('settings.version') }} {{ rootStore.versionCli }}
					</n8n-link>
				</div>
			</template>
		</n8n-menu>
	</div>
</template>

<style lang="scss" module>
.container {
	min-width: $sidebar-expanded-width;
	height: 100%;
	background-color: var(--color-background-xlight);
	border-right: var(--border-base);
	position: relative;
	overflow: auto;
}

.returnButton {
	padding: var(--spacing-s) var(--spacing-l);
	cursor: pointer;
	&:hover {
		color: var(--color-primary);
	}
}

.versionContainer {
	padding: var(--spacing-xs) var(--spacing-l);
}

@media screen and (max-height: 420px) {
	.versionContainer {
		display: none;
	}
}
</style>
