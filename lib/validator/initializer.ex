defmodule EctoValidator.Validator.Initializer do
  alias EctoValidator.{Information, Field}

  @doc """
  generates the required information to cast/validate the
  changeset
  """
  def build_types(groups) do
    groups
    |> Enum.reduce(
      %Information{},
      &build_group_types/2
    )
  end

  defp build_group_types(group, information) do
    {information, fields} = Enum.reduce(group.fields, {information, []}, &build_field_types/2)
    %{information | groups: [%{group | fields: fields} | information.groups]}
  end

  defp build_field_types(
         %{
           validations: validations,
           name: name,
           field_type: field_type,
           operation: operation,
           filter: filter,
           deftype: deftype,
           cast: cast,
           default: default,
           foreign_key: foreign_key
         },
         {%Information{} = token, fields}
       ) do
    foreign_key =
      cond do
        is_nil(foreign_key) and deftype not in [:field] ->
          String.to_atom("#{name}_id")

        is_atom(foreign_key) and not is_nil(foreign_key) ->
          foreign_key

        true ->
          nil
      end

    field = %Field{
      name: name,
      operation: operation,
      type: field_type,
      deftype: deftype,
      validations: validations,
      options: extract_options(validations),
      foreign_key: foreign_key,
      unique?: unique?(validations),
      filters: filter,
      cast?: cast,
      controlled?: controlled?(validations),
      default: default
    }

    token = build_field_types(field, token)
    {token, [field | fields]}
  end

  # operation types
  defp build_field_types(
         %Field{
           deftype: :field,
           type: type,
           operation: operation,
           name: name,
           validations: field_validations
         },
         %Information{
           types: types,
           validations: validations,
           operations: operations
         } = token
       )
       when not is_nil(operation) do
    %Information{
      token
      | types: Map.put(types, name, type),
        validations: Map.put(validations, name, field_validations),
        operations: Map.put(operations, name, operation)
    }
  end

  # regular types
  defp build_field_types(
         %Field{
           deftype: :field,
           type: type,
           name: name,
           validations: field_validations,
           default: default,
           cast?: cast?
         },
         %Information{
           types: types,
           defaults: defaults,
           validations: validations,
           fields_to_casts: fields_to_casts
         } = token
       ) do
    %Information{
      token
      | types: Map.put(types, name, type),
        validations: Map.put(validations, name, field_validations),
        defaults: Map.put(defaults, name, default),
        fields_to_casts: add_to_if_true(fields_to_casts, name, cast?)
    }
  end

  defp build_field_types(
         %Field{
           deftype: :belongs_to,
           name: name,
           validations: field_validations,
           foreign_key: foreign_key,
           type: type,
           cast?: cast?
         },
         %Information{
           types: types,
           validations: validations,
           assocs: assocs,
           fields_to_casts: fields_to_casts
         } = token
       ) do
    %Information{
      token
      | types: Map.put(types, foreign_key, :binary_id),
        validations:
          Map.merge(validations, %{name => field_validations, foreign_key => field_validations}),
        assocs: Map.put(assocs, name, type),
        fields_to_casts: add_to_if_true(fields_to_casts, foreign_key, cast?)
    }
  end

  defp build_field_types(
         %Field{
           deftype: :has_many,
           name: name,
           validations: field_validations,
           type: type,
           cast?: cast?
         },
         %Information{
           types: types,
           validations: validations,
           assocs: assocs,
           assocs_to_cast: assocs_to_cast
         } = token
       ) do
    %Information{
      token
      | types: Map.put(types, name, :binary_id),
        validations: Map.put(validations, name, field_validations),
        assocs: Map.put(assocs, name, type),
        assocs_to_cast: add_to_if_true(assocs_to_cast, name, cast?)
    }
  end

  defp add_to_if_true(list, value, true), do: [value | list]
  defp add_to_if_true(list, _value, _), do: list

  defp extract_options({:in, options}), do: options

  defp extract_options({:and, left, right}) do
    do_extract_options(left, right)
  end

  defp extract_options({:or, left, right}) do
    do_extract_options(left, right)
  end

  defp extract_options({:if, _, left, right}) do
    do_extract_options(left, right)
  end

  defp extract_options(_), do: nil

  defp do_extract_options(left, right) do
    case {extract_options(left), extract_options(right)} do
      {nil, nil} -> nil
      {nil, result} -> result
      {result, nil} -> result
      {options1, options2} -> Enum.uniq(options1 ++ options2)
    end
  end

  defp controlled?({:and, left, right}) do
    do_controlled?(left, right)
  end

  defp controlled?({:or, left, right}) do
    do_controlled?(left, right)
  end

  defp controlled?({:controlled, _}), do: true
  defp controlled?(_), do: false

  defp do_controlled?(left, right) do
    controlled?(left) or controlled?(right)
  end

  defp unique?({:unique, fields}), do: fields

  defp unique?({:and, left, right}) do
    do_unique(left, right)
  end

  defp unique?({:or, left, right}) do
    do_unique(left, right)
  end

  defp unique?(_), do: nil

  defp do_unique(left, right) do
    case {unique?(left), unique?(right)} do
      {_, result} when is_list(result) -> result
      {result, _} when is_list(result) -> result
      _ -> nil
    end
  end
end
