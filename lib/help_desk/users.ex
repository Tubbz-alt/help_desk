defmodule HelpDesk.Users do
  alias ZenEx.Entity.{Organization, User}
  alias Bottle.Account.V1.User, as: BottleUser

  def sync(%BottleUser{} = user) do
    user
    |> zendesk_attributes()
    |> ZenEx.Model.User.create()
    |> maybe_update_primary_email(user)
  end

  defp full_name(user), do: String.strip("#{user.first_name} #{user.last_name}")

  defp maybe_update_primary_email(%{email: email} = zendesk_user, %{email: email}) do
    zendesk_user
  end

  defp maybe_update_primary_email(zendesk_user, user) do
    with %{entites: identities} <- ZenEx.Model.Identity.list(zendesk_user),
         identity = Enum.find(identities, &(&1.value == user.email)),
         %{primary: true} <- ZenEx.Model.Identity.make_primary(identity) do
      zendesk_user
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_update_primary_email(error, _) do
    error
  end

  defp user_fields(%BottleUser{type: :ACCOUNT_TYPE_INDIVIDUAL} = user) do
    %{
      account_type: "individual",
      newsletter: user.newsletter
    }
  end

  defp user_fields(%User{} = user) do
    %{
      account_type: "business",
      company_name: user.company_name,
      reseller: user.type == :ACCOUNT_TYPE_RESELLER,
      newsletter: user.newsletter
    }
  end

  def zendesk_attributes(user) do
    %User{
      email: user.email,
      name: full_name(user),
      external_id: user.id,
      phone: user.phone_number,
      verified: true,
      user_fields: user_fields(user)
    }
  end
end
