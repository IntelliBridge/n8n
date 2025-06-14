import type {
	NavigationGuardNext,
	RouteRecordRaw,
	RouteLocationRaw,
	RouteLocationNormalized,
} from 'vue-router';
import { createRouter, createWebHistory, isNavigationFailure } from 'vue-router';
import { useExternalHooks } from '@/composables/useExternalHooks';
import { useSettingsStore } from '@/stores/settings.store';
import { useUIStore } from '@/stores/ui.store';
import { useSSOStore } from '@/stores/sso.store';
import { useTestDefinitionStore } from '@/stores/testDefinition.store.ee';
import { EnterpriseEditionFeature, VIEWS, EDITABLE_CANVAS_VIEWS } from '@/constants';
import { useTelemetry } from '@/composables/useTelemetry';
import { middleware } from '@/utils/rbac/middleware';
import type { RouterMiddleware } from '@/types/router';
import { initializeAuthenticatedFeatures, initializeCore } from '@/init';
import { projectsRoutes } from '@/routes/projects.routes';
import { insightsRoutes } from '@/features/insights/insights.router';
import TestDefinitionRunDetailView from './views/TestDefinition/TestDefinitionRunDetailView.vue';

const ChangePasswordView = async () => await import('./views/ChangePasswordView.vue');
const ErrorView = async () => await import('./views/ErrorView.vue');
const ForgotMyPasswordView = async () => await import('./views/ForgotMyPasswordView.vue');
const MainHeader = async () => await import('@/components/MainHeader/MainHeader.vue');
const MainSidebar = async () => await import('@/components/MainSidebar.vue');
const CanvasChatSwitch = async () => await import('@/components/CanvasChat/CanvasChatSwitch.vue');
const DemoFooter = async () =>
	await import('@/components/CanvasChat/future/components/DemoFooter.vue');
const NodeView = async () => await import('@/views/NodeView.vue');
const WorkflowExecutionsView = async () => await import('@/views/WorkflowExecutionsView.vue');
const WorkflowExecutionsLandingPage = async () =>
	await import('@/components/executions/workflow/WorkflowExecutionsLandingPage.vue');
const WorkflowExecutionsPreview = async () =>
	await import('@/components/executions/workflow/WorkflowExecutionsPreview.vue');
const SettingsView = async () => await import('./views/SettingsView.vue');
const SettingsLdapView = async () => await import('./views/SettingsLdapView.vue');
const SettingsPersonalView = async () => await import('./views/SettingsPersonalView.vue');
const SettingsUsersView = async () => await import('./views/SettingsUsersView.vue');
const SettingsCommunityNodesView = async () =>
	await import('./views/SettingsCommunityNodesView.vue');
const SettingsApiView = async () => await import('./views/SettingsApiView.vue');
const SettingsLogStreamingView = async () => await import('./views/SettingsLogStreamingView.vue');
const SetupView = async () => await import('./views/SetupView.vue');
const SigninView = async () => await import('./views/SigninView.vue');
const SignupView = async () => await import('./views/SignupView.vue');
const SettingsUsageAndPlan = async () => await import('./views/SettingsUsageAndPlan.vue');
const SettingsSso = async () => await import('./views/SettingsSso.vue');
const SignoutView = async () => await import('@/views/SignoutView.vue');
const SamlOnboarding = async () => await import('@/views/SamlOnboarding.vue');
const SettingsSourceControl = async () => await import('./views/SettingsSourceControl.vue');
const WorkerView = async () => await import('./views/WorkerView.vue');
const WorkflowHistory = async () => await import('@/views/WorkflowHistory.vue');
const WorkflowOnboardingView = async () => await import('@/views/WorkflowOnboardingView.vue');
const TestDefinitionListView = async () =>
	await import('./views/TestDefinition/TestDefinitionListView.vue');
const TestDefinitionNewView = async () =>
	await import('./views/TestDefinition/TestDefinitionNewView.vue');
const TestDefinitionEditView = async () =>
	await import('./views/TestDefinition/TestDefinitionEditView.vue');
const TestDefinitionRootView = async () =>
	await import('./views/TestDefinition/TestDefinitionRootView.vue');

export const routes: RouteRecordRaw[] = [
	{
		path: '/',
		redirect: '/home/workflows',
		meta: {
			middleware: ['authenticated'],
		},
	},
	{
		path: '/workflow/:name/debug/:executionId',
		name: VIEWS.EXECUTION_DEBUG,
		components: {
			default: NodeView,
			header: MainHeader,
			sidebar: MainSidebar,
		},
		meta: {
			nodeView: true,
			keepWorkflowAlive: true,
			middleware: ['authenticated', 'enterprise'],
			middlewareOptions: {
				enterprise: {
					feature: [EnterpriseEditionFeature.DebugInEditor],
				},
			},
		},
	},
	{
		path: '/workflow/:name/executions',
		name: VIEWS.WORKFLOW_EXECUTIONS,
		components: {
			default: WorkflowExecutionsView,
			header: MainHeader,
			sidebar: MainSidebar,
		},
		meta: {
			keepWorkflowAlive: true,
			middleware: ['authenticated'],
		},
		children: [
			{
				path: '',
				name: VIEWS.EXECUTION_HOME,
				components: {
					executionPreview: WorkflowExecutionsLandingPage,
				},
				meta: {
					keepWorkflowAlive: true,
					middleware: ['authenticated'],
				},
			},
			{
				path: ':executionId',
				name: VIEWS.EXECUTION_PREVIEW,
				components: {
					executionPreview: WorkflowExecutionsPreview,
				},
				meta: {
					keepWorkflowAlive: true,
					middleware: ['authenticated'],
				},
			},
		],
	},
	{
		path: '/workflow/:name/evaluation',
		components: {
			default: TestDefinitionRootView,
			header: MainHeader,
			sidebar: MainSidebar,
		},
		props: true,
		meta: {
			keepWorkflowAlive: true,
			middleware: ['authenticated', 'custom'],
			middlewareOptions: {
				custom: () => useTestDefinitionStore().isFeatureEnabled,
			},
		},
		children: [
			{
				path: '',
				name: VIEWS.TEST_DEFINITION,
				component: TestDefinitionListView,
				props: true,
			},
			{
				path: 'new',
				name: VIEWS.NEW_TEST_DEFINITION,
				component: TestDefinitionNewView,
				props: true,
			},
			{
				path: ':testId',
				name: VIEWS.TEST_DEFINITION_EDIT,
				props: true,
				components: {
					default: TestDefinitionEditView,
				},
			},
			{
				path: ':testId/runs/:runId',
				name: VIEWS.TEST_DEFINITION_RUNS_DETAIL,
				props: true,
				components: {
					default: TestDefinitionRunDetailView,
				},
			},
		],
	},
	{
		path: '/workflow/:workflowId/history/:versionId?',
		name: VIEWS.WORKFLOW_HISTORY,
		components: {
			default: WorkflowHistory,
			sidebar: MainSidebar,
		},
		meta: {
			middleware: ['authenticated', 'enterprise'],
			middlewareOptions: {
				enterprise: {
					feature: [EnterpriseEditionFeature.WorkflowHistory],
				},
			},
		},
	},
	{
		path: '/workflows/templates/:id',
		name: VIEWS.TEMPLATE_IMPORT,
		components: {
			default: NodeView,
			header: MainHeader,
			sidebar: MainSidebar,
		},
		meta: {
			templatesEnabled: true,
			keepWorkflowAlive: true,
			middleware: ['authenticated'],
		},
	},
	{
		path: '/workflows/onboarding/:id',
		name: VIEWS.WORKFLOW_ONBOARDING,
		components: {
			default: WorkflowOnboardingView,
			header: MainHeader,
			sidebar: MainSidebar,
		},
		meta: {
			templatesEnabled: true,
			keepWorkflowAlive: true,
			middleware: ['authenticated'],
		},
	},
	{
		path: '/workflow/new',
		name: VIEWS.NEW_WORKFLOW,
		components: {
			default: NodeView,
			header: MainHeader,
			sidebar: MainSidebar,
			footer: CanvasChatSwitch,
		},
		meta: {
			nodeView: true,
			keepWorkflowAlive: true,
			middleware: ['authenticated'],
		},
	},
	{
		path: '/workflows/demo',
		name: VIEWS.DEMO,
		components: {
			default: NodeView,
			footer: DemoFooter,
		},
		meta: {
			middleware: ['authenticated'],
			middlewareOptions: {
				authenticated: {
					bypass: () => {
						const settingsStore = useSettingsStore();
						return settingsStore.isPreviewMode;
					},
				},
			},
		},
	},
	{
		path: '/workflow/:name',
		name: VIEWS.WORKFLOW,
		components: {
			default: NodeView,
			header: MainHeader,
			sidebar: MainSidebar,
			footer: CanvasChatSwitch,
		},
		meta: {
			nodeView: true,
			keepWorkflowAlive: true,
			middleware: ['authenticated'],
		},
	},
	{
		path: '/workflow',
		redirect: '/workflow/new',
	},
	{
		path: '/signin',
		name: VIEWS.SIGNIN,
		components: {
			default: SigninView,
		},
		meta: {
			telemetry: {
				pageCategory: 'auth',
			},
			middleware: ['guest'],
		},
	},
	{
		path: '/signup',
		name: VIEWS.SIGNUP,
		components: {
			default: SignupView,
		},
		meta: {
			telemetry: {
				pageCategory: 'auth',
			},
			middleware: ['guest'],
		},
	},
	{
		path: '/signout',
		name: VIEWS.SIGNOUT,
		components: {
			default: SignoutView,
		},
		meta: {
			telemetry: {
				pageCategory: 'auth',
			},
			middleware: ['authenticated'],
		},
	},
	{
		path: '/setup',
		name: VIEWS.SETUP,
		components: {
			default: SetupView,
		},
		meta: {
			middleware: ['defaultUser'],
			telemetry: {
				pageCategory: 'auth',
			},
		},
	},
	{
		path: '/forgot-password',
		name: VIEWS.FORGOT_PASSWORD,
		components: {
			default: ForgotMyPasswordView,
		},
		meta: {
			middleware: ['guest'],
			telemetry: {
				pageCategory: 'auth',
			},
		},
	},
	{
		path: '/change-password',
		name: VIEWS.CHANGE_PASSWORD,
		components: {
			default: ChangePasswordView,
		},
		meta: {
			middleware: ['guest'],
			telemetry: {
				pageCategory: 'auth',
			},
		},
	},
	{
		path: '/settings',
		name: VIEWS.SETTINGS,
		component: SettingsView,
		props: true,
		redirect: () => {
			const settingsStore = useSettingsStore();
			if (settingsStore.settings.hideUsagePage) {
				return { name: VIEWS.PERSONAL_SETTINGS };
			}
			return { name: VIEWS.USAGE };
		},
		children: [
			{
				path: 'usage',
				name: VIEWS.USAGE,
				components: {
					settingsView: SettingsUsageAndPlan,
				},
				meta: {
					middleware: ['authenticated', 'custom'],
					middlewareOptions: {
						custom: () => {
							const settingsStore = useSettingsStore();
							return !settingsStore.settings.hideUsagePage;
						},
					},
					telemetry: {
						pageCategory: 'settings',
						getProperties() {
							return {
								feature: 'usage',
							};
						},
					},
				},
			},
			{
				path: 'personal',
				name: VIEWS.PERSONAL_SETTINGS,
				components: {
					settingsView: SettingsPersonalView,
				},
				meta: {
					middleware: ['authenticated'],
					telemetry: {
						pageCategory: 'settings',
						getProperties() {
							return {
								feature: 'personal',
							};
						},
					},
				},
			},
			{
				path: 'users',
				name: VIEWS.USERS_SETTINGS,
				components: {
					settingsView: SettingsUsersView,
				},
				meta: {
					middleware: ['authenticated', 'rbac'],
					middlewareOptions: {
						rbac: {
							scope: ['user:create', 'user:update'],
						},
					},
					telemetry: {
						pageCategory: 'settings',
						getProperties() {
							return {
								feature: 'users',
							};
						},
					},
				},
			},
			{
				path: 'api',
				name: VIEWS.API_SETTINGS,
				components: {
					settingsView: SettingsApiView,
				},
				meta: {
					middleware: ['authenticated'],
					telemetry: {
						pageCategory: 'settings',
						getProperties() {
							return {
								feature: 'api',
							};
						},
					},
				},
			},
			{
				path: 'environments',
				name: VIEWS.SOURCE_CONTROL,
				components: {
					settingsView: SettingsSourceControl,
				},
				meta: {
					middleware: ['authenticated', 'rbac'],
					middlewareOptions: {
						rbac: {
							scope: 'sourceControl:manage',
						},
					},
					telemetry: {
						pageCategory: 'settings',
						getProperties() {
							return {
								feature: 'environments',
							};
						},
					},
				},
			},
			{
				path: 'sso',
				name: VIEWS.SSO_SETTINGS,
				components: {
					settingsView: SettingsSso,
				},
				meta: {
					middleware: ['authenticated', 'rbac'],
					middlewareOptions: {
						rbac: {
							scope: 'saml:manage',
						},
					},
					telemetry: {
						pageCategory: 'settings',
						getProperties() {
							return {
								feature: 'sso',
							};
						},
					},
				},
			},
			{
				path: 'log-streaming',
				name: VIEWS.LOG_STREAMING_SETTINGS,
				components: {
					settingsView: SettingsLogStreamingView,
				},
				meta: {
					middleware: ['authenticated', 'rbac'],
					middlewareOptions: {
						rbac: {
							scope: 'logStreaming:manage',
						},
					},
					telemetry: {
						pageCategory: 'settings',
					},
				},
			},
			{
				path: 'workers',
				name: VIEWS.WORKER_VIEW,
				components: {
					settingsView: WorkerView,
				},
				meta: {
					middleware: ['authenticated'],
				},
			},
			{
				path: 'community-nodes',
				name: VIEWS.COMMUNITY_NODES,
				components: {
					settingsView: SettingsCommunityNodesView,
				},
				meta: {
					middleware: ['authenticated', 'rbac', 'custom'],
					middlewareOptions: {
						rbac: {
							scope: ['communityPackage:list', 'communityPackage:update'],
						},
						custom: () => {
							const settingsStore = useSettingsStore();
							return settingsStore.isCommunityNodesFeatureEnabled;
						},
					},
					telemetry: {
						pageCategory: 'settings',
					},
				},
			},
			{
				path: 'ldap',
				name: VIEWS.LDAP_SETTINGS,
				components: {
					settingsView: SettingsLdapView,
				},
				meta: {
					middleware: ['authenticated', 'rbac'],
					middlewareOptions: {
						rbac: {
							scope: 'ldap:manage',
						},
					},
				},
			},
		],
	},
	{
		path: '/saml/onboarding',
		name: VIEWS.SAML_ONBOARDING,
		components: {
			default: SamlOnboarding,
		},
		meta: {
			middleware: ['authenticated', 'custom'],
			middlewareOptions: {
				custom: () => {
					const settingsStore = useSettingsStore();
					const ssoStore = useSSOStore();
					return ssoStore.isEnterpriseSamlEnabled && !settingsStore.isCloudDeployment;
				},
			},
			telemetry: {
				pageCategory: 'auth',
			},
		},
	},
	...projectsRoutes,
	...insightsRoutes,
	{
		path: '/:pathMatch(.*)*',
		name: VIEWS.NOT_FOUND,
		component: ErrorView,
		props: {
			messageKey: 'error.pageNotFound',
			errorCode: 404,
			redirectTextKey: 'error.goBack',
			redirectPage: VIEWS.HOMEPAGE,
		},
		meta: {
			nodeView: true,
			telemetry: {
				disabled: true,
			},
		},
	},
];

function withCanvasReadOnlyMeta(route: RouteRecordRaw) {
	if (!route.meta) {
		route.meta = {};
	}
	route.meta.readOnlyCanvas = !EDITABLE_CANVAS_VIEWS.includes((route?.name ?? '') as VIEWS);

	if (route.children) {
		route.children = route.children.map(withCanvasReadOnlyMeta);
	}

	return route;
}

const router = createRouter({
	history: createWebHistory(import.meta.env.DEV ? '/' : (window.BASE_PATH ?? '/')),
	scrollBehavior(to: RouteLocationNormalized, _, savedPosition) {
		// saved position == null means the page is NOT visited from history (back button)
		if (savedPosition === null && to.name === VIEWS.TEMPLATES && to.meta?.setScrollPosition) {
			// for templates view, reset scroll position in this case
			to.meta.setScrollPosition(0);
		}
	},
	routes: routes.map(withCanvasReadOnlyMeta),
});

router.beforeEach(async (to: RouteLocationNormalized, from, next) => {
	try {
		/**
		 * Initialize application core
		 * This step executes before first route is loaded and is required for permission checks
		 */

		await initializeCore();
		await initializeAuthenticatedFeatures();

		/**
		 * Redirect to setup page. User should be redirected to this only once
		 */

		const settingsStore = useSettingsStore();
		if (settingsStore.showSetupPage) {
			if (to.name === VIEWS.SETUP) {
				return next();
			}

			return next({ name: VIEWS.SETUP });
		}

		/**
		 * Verify user permissions for current route
		 */

		const routeMiddleware = to.meta?.middleware ?? [];
		const routeMiddlewareOptions = to.meta?.middlewareOptions ?? {};
		for (const middlewareName of routeMiddleware) {
			let nextCalled = false;
			const middlewareNext = ((location: RouteLocationRaw): void => {
				next(location);
				nextCalled = true;
			}) as NavigationGuardNext;

			const middlewareOptions = routeMiddlewareOptions[middlewareName];
			const middlewareFn = middleware[middlewareName] as RouterMiddleware<unknown>;
			await middlewareFn(to, from, middlewareNext, middlewareOptions);

			if (nextCalled) {
				return;
			}
		}

		return next();
	} catch (failure) {
		if (isNavigationFailure(failure)) {
			console.log(failure);
		} else {
			console.error(failure);
		}
	}
});

router.afterEach((to, from) => {
	try {
		const telemetry = useTelemetry();
		const uiStore = useUIStore();

		/**
		 * Run external hooks
		 */

		void useExternalHooks().run('main.routeChange', { from, to });

		/**
		 * Track current view for telemetry
		 */

		uiStore.currentView = (to.name as string) ?? '';
		telemetry.page(to);
	} catch (failure) {
		if (isNavigationFailure(failure)) {
			console.log(failure);
		} else {
			console.error(failure);
		}
	}
});

export default router;
