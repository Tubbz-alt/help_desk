defmodule HelpDesk.Organizations do
  alias ZenEx.Entity.Organization

  def create(%{id: id, name: name}) do
    ZenEx.Model.Organization.create(%Organization{external_id: id, name: name})
  end
end
