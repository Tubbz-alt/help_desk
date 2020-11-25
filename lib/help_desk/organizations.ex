defmodule HelpDesk.Organizations do
  alias ZenEx.Entity.Organization

  def create(%{id: id, name: name}) do
    ZenEx.Model.Organization.create(%Organization{external_id: id, name: name})
  end

  def join(%{organization: organization, user: user}) do
    with %{entities: [zendesk_user]} <- ZenEx.Model.User.search(external_id: user.id),
         %{entities: [zendesk_organization]} <- ZenEx.Model.Organization.search(external_id: organization.id) do
      ZenEx.Model.OrganizationMembership.create(zendesk_organization, zendesk_user)
    end
  end

  def leave(%{user: user}) do
    with %{entities: [zendesk_user]} <- ZenEx.Model.User.search(external_id: user.id),
         %{entities: [%{id: organization_membership_id]} <- ZenEx.Model.OrganizationMembership.list(zendesk_user) do
      ZenEx.Model.OrganizationMembership.destroy(organization_membership_id)
    end
  end
end
