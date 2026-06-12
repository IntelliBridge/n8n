import { createPinia } from 'pinia';
import { waitFor } from '@testing-library/vue';
import { waitAllPromises, getTooltip, hoverTooltipTrigger } from '@/__tests__/utils';
import SettingsPersonalView from './SettingsPersonalView.vue';
import { useSettingsStore } from '@/app/stores/settings.store';
import { useUsersStore } from '@/features/settings/users/users.store';
import { createComponentRenderer } from '@/__tests__/render';
import { setupServer } from '@/__tests__/server';
import { ROLE } from '@n8n/api-types';
import { useCloudPlanStore } from '@/app/stores/cloudPlan.store';
import { useSSOStore } from '@/features/settings/sso/sso.store';
import { UserManagementAuthenticationMethod } from '@/Interface';

let pinia: ReturnType<typeof createPinia>;
let settingsStore: ReturnType<typeof useSettingsStore>;
let ssoStore: ReturnType<typeof useSSOStore>;
let usersStore: ReturnType<typeof useUsersStore>;
let cloudPlanStore: ReturnType<typeof useCloudPlanStore>;
let server: ReturnType<typeof setupServer>;

const renderComponent = createComponentRenderer(SettingsPersonalView);

const currentUser = {
	id: '1',
	firstName: 'John',
	lastName: 'Doe',
	email: 'joh.doe@example.com',
	createdAt: Date().toString(),
	role: ROLE.Owner,
	isDefaultUser: false,
	isPendingUser: false,
	isPending: false,
	mfaEnabled: false,
};

describe('SettingsPersonalView', () => {
	beforeAll(() => {
		server = setupServer();
	});

	beforeEach(async () => {
		pinia = createPinia();

		settingsStore = useSettingsStore(pinia);
		ssoStore = useSSOStore(pinia);
		usersStore = useUsersStore(pinia);
		cloudPlanStore = useCloudPlanStore(pinia);

		usersStore.usersById[currentUser.id] = currentUser;
		usersStore.currentUserId = currentUser.id;

		await settingsStore.getSettings();
		ssoStore.initialize({
			authenticationMethod: UserManagementAuthenticationMethod.Email,
			config: settingsStore.settings.sso,
			features: {
				saml: true,
				ldap: true,
				oidc: true,
			},
		});
	});

	afterAll(() => {
		server.shutdown();
	});

	it('should enable email and pw change', async () => {
		const { getByTestId, getAllByRole } = renderComponent({ pinia });
		await waitAllPromises();

		expect(getAllByRole('textbox').find((el) => el.getAttribute('type') === 'email')).toBeEnabled();
		expect(getByTestId('change-password-link')).toBeInTheDocument();
	});

	// Flow ships dark-only: the theme picker is removed from this view
	describe('theme picker (removed)', () => {
		it('should disable save button when nothing has been changed', async () => {
			const { getByTestId } = renderComponent({ pinia });
			await waitAllPromises();

			expect(getByTestId('save-settings-button')).toBeDisabled();
		});

		it('should not render a theme select', async () => {
			const { queryByTestId } = renderComponent({ pinia });
			await waitAllPromises();

			expect(queryByTestId('theme-select')).not.toBeInTheDocument();
		});
	});

	describe('when external auth is enabled, email and password change', () => {
		beforeEach(() => {
			vi.spyOn(ssoStore, 'isSamlLoginEnabled', 'get').mockReturnValue(true);
			vi.spyOn(ssoStore, 'isDefaultAuthenticationSaml', 'get').mockReturnValue(true);
			vi.spyOn(settingsStore, 'isMfaFeatureEnabled', 'get').mockReturnValue(true);
		});

		it('should not be disabled for the instance owner', async () => {
			vi.spyOn(usersStore, 'isInstanceOwner', 'get').mockReturnValue(true);

			const { queryByTestId, getAllByRole } = renderComponent({ pinia });
			await waitAllPromises();

			expect(
				getAllByRole('textbox').find((el) => el.getAttribute('type') === 'email'),
			).toBeEnabled();
			expect(queryByTestId('change-password-link')).toBeInTheDocument();
			expect(queryByTestId('mfa-section')).toBeInTheDocument();
		});

		it('should be disabled for members', async () => {
			vi.spyOn(usersStore, 'isInstanceOwner', 'get').mockReturnValue(false);

			const { queryByTestId, getAllByRole } = renderComponent({ pinia });
			await waitAllPromises();

			expect(
				getAllByRole('textbox').find((el) => el.getAttribute('type') === 'email'),
			).toBeDisabled();
			expect(queryByTestId('change-password-link')).not.toBeInTheDocument();
			expect(queryByTestId('mfa-section')).not.toBeInTheDocument();
		});
	});

	test.each([
		['Default', ROLE.Default, false, 'Default role for new users'],
		['Member', ROLE.Member, false, 'Create and manage own workflows and credentials'],
		['Admin', ROLE.Admin, false, 'Full access to manage workflows'],
		['Owner', ROLE.Owner, false, 'Manage everything'],
		['Owner', ROLE.Owner, true, 'Manage everything and access Cloud dashboard'],
	])(
		'should show %s user role information with tooltip',
		async (label, role, hasCloudPlan, expectedTooltip) => {
			vi.spyOn(cloudPlanStore, 'hasCloudPlan', 'get').mockReturnValue(hasCloudPlan);
			vi.spyOn(usersStore, 'globalRoleName', 'get').mockReturnValue(role);

			const { queryByTestId } = renderComponent({ pinia });
			await waitAllPromises();

			const roleElement = queryByTestId('current-user-role');
			expect(roleElement).toBeVisible();
			expect(roleElement).toHaveTextContent(label);

			// Hover and verify tooltip content
			if (roleElement) {
				await hoverTooltipTrigger(roleElement);
				await waitFor(() => expect(getTooltip()).toHaveTextContent(expectedTooltip));
			}
		},
	);
});
