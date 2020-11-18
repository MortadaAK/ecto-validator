defmodule EctoValidator.Validator do
  @moduledoc """
  API to build and validate documents from inputs (map) and schema.
  This builder will generates
  """
  alias Ecto.Changeset
  alias EctoValidator.{Information, Validator.Runner}
  require Logger

  @date_types [
    :today,
    :beginning_of_month,
    :beginning_of_quarter,
    :beginning_of_year,
    :beginning_of_week,
    :end_of_month,
    :end_of_quarter,
    :end_of_year,
    :end_of_week
  ]

  def changeset(
        %Information{
          types: types,
          fields_to_casts: fields_to_casts,
          assocs_to_cast: assocs_to_cast
        } = information,
        source,
        params
      ) do
    source
    |> Changeset.cast(ensure_keys_are_string(params), fields_to_casts)
    |> put_defaults(information)
    |> nested_changeset(information, assocs_to_cast)
    |> calculate_operations(information)
    |> validate_fields_types(information, Map.keys(types))
    |> Runner.validate_fields(information, Map.keys(types))
  end

  defp nested_changeset(changeset, _information, []), do: changeset

  defp nested_changeset(changeset, information, [name | rem]) do
    changeset
    |> Changeset.cast_assoc(name,
      with: fn %schema{} = record, params ->
        information = apply(schema, :__information__, [])
        changeset(information, record, params)
      end
    )
    |> validate_nested_changeset(name)
    |> nested_changeset(information, rem)
  end

  defp validate_nested_changeset(changeset, type) do
    with [_ | _] = list <- Changeset.get_field(changeset, type),
         true <- Enum.any?(list, &invalid_nested_changeset?/1) do
      Changeset.add_error(changeset, type, "is invalid", type: :assoc, validation: :cast)
    else
      _ -> changeset
    end
  end

  defp invalid_nested_changeset?(%Ecto.Changeset{valid?: false}), do: true
  defp invalid_nested_changeset?(_), do: false

  # incase of nested records
  defp validate_fields_types(changeset, _information, [module, type])
       when is_atom(module) and is_binary(type),
       do: changeset

  # this is needed for database type constraints such as a string field should not be more than 255
  defp validate_fields_types(changeset, information, fields) when is_list(fields) do
    Enum.reduce(fields, changeset, fn field, changeset ->
      validate_fields_types(
        changeset,
        field,
        Map.get(information.types, field)
      )
    end)
  end

  defp validate_fields_types(changeset, field, :string) do
    Changeset.validate_length(changeset, field, max: 255)
  end

  defp validate_fields_types(changeset, _field, _type), do: changeset

  defp put_defaults(changeset, %Information{} = information) do
    Enum.reduce(information.defaults, changeset, &put_default/2)
  end

  defp put_default({_field, nil}, changeset), do: changeset

  defp put_default({field, type}, changeset) do
    if Changeset.get_field(changeset, field) == nil do
      do_put_default({field, type}, changeset)
    else
      changeset
    end
  end

  defp do_put_default({field, type}, changeset)
       when type in @date_types do
    Changeset.put_change(changeset, field, __MODULE__.Utils.resolve_date(type))
  end

  defp do_put_default({field, value}, changeset) do
    Changeset.put_change(changeset, field, value)
  end

  defp calculate_operations(changeset, information) do
    fields = Map.keys(information.operations)

    information.types
    |> Enum.filter(fn {key, _} -> Enum.any?(fields, &(&1 == key)) end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.reduce(changeset, fn field, changeset ->
      __MODULE__.Utils.ensure_variable(changeset, information, field)
    end)
  end

  defp ensure_keys_are_string(struct) when is_struct(struct), do: struct

  defp ensure_keys_are_string(%{} = map) do
    map
    |> Enum.map(&ensure_keys_are_string/1)
    |> Map.new()
  end

  defp ensure_keys_are_string({atom, value}) when is_atom(atom) do
    {Atom.to_string(atom), ensure_keys_are_string(value)}
  end

  defp ensure_keys_are_string({string, value}) do
    {string, ensure_keys_are_string(value)}
  end

  defp ensure_keys_are_string(list) when is_list(list) do
    Enum.map(list, &ensure_keys_are_string/1)
  end

  defp ensure_keys_are_string(value), do: value
end
