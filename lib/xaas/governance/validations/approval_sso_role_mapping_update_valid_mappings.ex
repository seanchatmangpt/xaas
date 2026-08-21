defmodule Xaas.Governance.Validations.ApprovalSsoRoleMappingUpdateValidMappings do
  @moduledoc """
  Real structural validation, ported from platform-console's
  `validateSsoGroupMappings` (`app/lib/sso-role-mapping.ts`): rejects a
  non-list payload, more than `MAX_MAPPINGS` (100) entries, any entry
  missing a non-empty `ssoGroup` (max 256 chars) or a `role` outside
  `Xaas.Governance.Types.OrgRole`'s values, and any duplicate `ssoGroup`
  within the same submitted set.
  """
  use Ash.Resource.Validation

  @max_group_name_length 256
  @max_mappings 100
  @valid_roles Xaas.Governance.Types.OrgRole.values() |> Enum.map(&to_string/1)

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :requested_mappings) do
      mappings when is_list(mappings) ->
        cond do
          length(mappings) > @max_mappings ->
            {:error,
             field: :requested_mappings,
             message: "must contain at most #{@max_mappings} entries"}

          true ->
            check_entries(mappings)
        end

      _ ->
        {:error, field: :requested_mappings, message: "must be an array"}
    end
  end

  defp check_entries(mappings) do
    Enum.reduce_while(mappings, {:ok, MapSet.new()}, fn raw, {:ok, seen} ->
      entry = normalize_entry(raw)
      sso_group = String.trim(to_string(entry["ssoGroup"] || entry[:ssoGroup] || ""))
      role = to_string(entry["role"] || entry[:role] || "")

      cond do
        sso_group == "" or String.length(sso_group) > @max_group_name_length ->
          {:halt,
           {:error,
            field: :requested_mappings,
            message:
              "ssoGroup is required and must be at most #{@max_group_name_length} characters"}}

        role not in @valid_roles ->
          {:halt,
           {:error,
            field: :requested_mappings,
            message: "role must be one of: #{Enum.join(@valid_roles, ", ")}"}}

        MapSet.member?(seen, sso_group) ->
          {:halt,
           {:error,
            field: :requested_mappings,
            message: "duplicate ssoGroup in mapping set: '#{sso_group}'"}}

        true ->
          {:cont, {:ok, MapSet.put(seen, sso_group)}}
      end
    end)
    |> case do
      {:ok, _seen} -> :ok
      {:error, _} = error -> error
    end
  end

  defp normalize_entry(entry) when is_map(entry), do: entry
  defp normalize_entry(_), do: %{}
end
