<script setup lang="ts">
import { computed, useCssModule } from 'vue';

import LogoIcon from './logo-icon.svg';
import LogoText from './logo-text.svg';

const props = defineProps<
	(
		| {
				size: 'large';
		  }
		| {
				size: 'small';
				collapsed: boolean;
		  }
	) & {
		releaseChannel?: 'stable' | 'beta' | 'nightly' | 'dev' | 'rc';
	}
>();

// Flow brand: releaseChannel stays in the props contract for callers, but the
// Workforce mark keeps its intrinsic colors on every channel and the favicon
// stays the static /favicon.ico (upstream recolored the logo + favicon here).
const { size } = props;

const showLogoText = computed(() => {
	if (size === 'large') return true;
	return !props.collapsed;
});

const $style = useCssModule();
const containerClasses = computed(() => {
	if (size === 'large') {
		return [$style.logoContainer, $style.large];
	}
	return [
		$style.logoContainer,
		$style.sidebar,
		props.collapsed ? $style.sidebarCollapsed : $style.sidebarExpanded,
	];
});

</script>

<template>
	<div :class="containerClasses" data-test-id="n8n-logo">
		<LogoIcon :class="$style.logo" />
		<LogoText v-if="showLogoText" :class="$style.logoText" />
		<slot />
	</div>
</template>

<style lang="scss" module>
.logoContainer {
	display: flex;
	justify-content: center;
	align-items: center;
}

.logoText {
	margin-left: var(--spacing--5xs);
	width: 4rem;
}

.large {
	transform: scale(2);
	margin-bottom: var(--spacing--xl);

	.logo,
	.logoText {
		transform: scale(1.3) translateY(-2px);
	}

	.logoText {
		margin-left: var(--spacing--xs);
		margin-right: var(--spacing--3xs);
	}
}

.sidebarExpanded .logo {
	margin-left: var(--spacing--2xs);
}

.sidebarCollapsed .logo {
	width: 40px;
	height: 30px;
	padding: 0 var(--spacing--4xs);
}
</style>
