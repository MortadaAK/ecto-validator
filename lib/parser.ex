defmodule EctoValidator.Parser do
  @deftype [:field, :has_one, :has_many, :belongs_to, :many_to_many]
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
  def parse_groups(groups, caller) do
    groups
    |> block_to_list()
    |> parse_groups(caller, [])
  end

  defp block_to_list({:__block__, _, list}), do: list
  defp block_to_list({_, _, _} = single_item), do: [single_item]

  defp parse_groups([], _caller, parsed_groups), do: parsed_groups

  defp parse_groups([group | groups], caller, parsed_groups) do
    parse_groups(groups, caller, [
      parse_group(group, caller) | parsed_groups
    ])
  end

  defp parse_group({:group, info, [[do: block]]}, caller),
    do: parse_group({:group, info, [[], [do: block]]}, caller)

  defp parse_group({:group, info, [options, [do: block]]}, caller) do
    {validations, options} = Keyword.pop(options, :validations)

    fields =
      block
      |> block_to_list()
      |> parse_fields(caller)

    %{
      options: options,
      fields: fields,
      info: info,
      validations: parse(validations, nil, caller)
    }
  end

  defp parse_group({deftype, info, params}, caller)
       when deftype in @deftype do
    %{
      options: [],
      info: info,
      fields: parse_fields([{deftype, info, params}], caller)
    }
  end

  defp parse_fields(fields, caller, parsed_fields \\ [])

  defp parse_fields([], _caller, parsed_fields),
    do: parsed_fields

  defp parse_fields(
         [field | fields],
         caller,
         parsed_fields
       ) do
    parse_fields(fields, caller, [
      parse_field(field, caller) | parsed_fields
    ])
  end

  def parse_field({deftype, info, [name, field_type]}, caller),
    do: parse_field({deftype, info, [name, field_type, []]}, caller)

  def parse_field({deftype, info, [name, field_type, options]}, caller)
      when deftype in @deftype and is_list(options) do
    {validations, options} = Keyword.pop(options, :validations)
    {operation, options} = Keyword.pop(options, :operation)
    {filter, options} = Keyword.pop(options, :filter)
    {default, options} = Keyword.pop(options, :default)
    foreign_key = Keyword.get(options, :foreign_key)

    {cast, options} =
      case Keyword.pop(options, :cast) do
        {value, options} when value in [true, false] -> {value, options}
        {_, options} when deftype in [:field, :belongs_to] -> {true, options}
        {_, options} -> {false, options}
      end

    %{
      validations: parse(validations, field_type, caller),
      name: name,
      field_type: field_type,
      options: options,
      foreign_key: foreign_key,
      operation: parse(operation, field_type, caller),
      filter: filter,
      default: default,
      deftype: deftype,
      info: info,
      cast: cast
    }
  end

  defp parse(number, _type, _caller) when is_number(number), do: number
  defp parse(string, _type, _caller) when is_binary(string), do: string
  defp parse(nil, _type, _caller), do: nil

  defp parse({{:., _, _}, _, _} = value, _type, _caller) do
    {value, []} = Code.eval_quoted(value)
    value
  end

  defp parse([validator], type, caller), do: parse(validator, type, caller)

  defp parse({:_, _, nil}, _type, _caller), do: :self

  defp parse({:not, _, condition}, type, caller) do
    {:not, parse(condition, type, caller)}
  end

  defp parse({:==, _, [left, right]}, type, caller) do
    {:eq, parse(left, type, caller), parse(right, type, caller)}
  end

  defp parse({:!=, _, [left, right]}, type, caller) do
    {:not, {:eq, parse(left, type, caller), parse(right, type, caller)}}
  end

  defp parse({:>, _, [left, right]}, type, caller) do
    {:gt, parse(left, type, caller), parse(right, type, caller)}
  end

  defp parse({:>=, _, [left, right]}, type, caller) do
    {:gteq, parse(left, type, caller), parse(right, type, caller)}
  end

  defp parse({:<, _, [left, right]}, type, caller) do
    {:lt, parse(left, type, caller), parse(right, type, caller)}
  end

  defp parse({:<=, _, [left, right]}, type, caller) do
    {:lteq, parse(left, type, caller), parse(right, type, caller)}
  end

  defp parse({:+, _, [left, right]}, type, caller) do
    {:add, parse(left, type, caller), parse(right, type, caller)}
  end

  defp parse({:-, _, [left, right]}, type, caller) do
    {:subt, parse(left, type, caller), parse(right, type, caller)}
  end

  defp parse({:*, _, [left, right]}, type, caller) do
    {:mult, parse(left, type, caller), parse(right, type, caller)}
  end

  defp parse({:/, _, [left, right]}, type, caller) do
    {:div, parse(left, type, caller), parse(right, type, caller)}
  end

  defp parse({:pow, _, [left, right]}, type, caller) do
    {:pow, parse(left, type, caller), parse(right, type, caller)}
  end

  defp parse({:and, _, [left, right]}, type, caller) do
    {:and, parse(left, type, caller), parse(right, type, caller)}
  end

  defp parse({:or, _, [left, right]}, type, caller) do
    {:or, parse(left, type, caller), parse(right, type, caller)}
  end

  defp parse({constraint, _, [index_name]}, _type, _caller)
       when constraint in [:unique, :check, :assoc] and is_binary(index_name),
       do: {constraint, index_name}

  defp parse(:required, _type, _caller),
    do: :required

  defp parse({:required, _, _}, _type, _caller),
    do: :required

  # string validations
  # matches ~r/a-z/
  defp parse({:matches, _, [regex]}, :string, _caller),
    do: {:matches, regex |> Code.eval_quoted() |> elem(0)}

  # _ in {Module,:function}
  defp parse(
         {:in, _, [_, {module, function_name}]},
         _type,
         caller
       ) do
    module = Macro.expand(module, caller)

    {:in, {:controlled, {module, function_name}}}
  end

  defp parse(
         {:in, _, [_, function_name]},
         _type,
         _caller
       )
       when is_atom(function_name) do
    {:in, {:controlled, function_name}}
  end

  # _ in ~w(1 2 3)
  defp parse({:in, _, [_, {_, _, _} = quoted]}, _type, caller),
    do: {:in, Macro.expand(quoted, caller)}

  # _ in [1,2,3]
  defp parse({:in, _, [_, list]}, _type, _caller) when is_list(list),
    do: {:in, list |> Code.eval_quoted() |> elem(0)}

  # string and nested records
  defp parse({:min, _, [number]}, _type, _caller) when is_number(number) do
    {:min, number}
  end

  defp parse({:max, _, [number]}, _type, _caller) when is_number(number) do
    {:max, number}
  end

  defp parse({operation, _, [field]}, _type, _caller)
       when is_atom(field) and operation in [:sum, :min, :max] do
    {operation, {:field, field}}
  end

  defp parse({operation, _, [nested, field]}, _type, _caller)
       when is_atom(nested) and is_atom(field) and operation in [:sum, :min, :max] do
    {operation, nested, field}
  end

  defp parse({operation, _, [value]}, type, caller)
       when type in [:date] and
              operation in [:days, :months, :weeks, :years] do
    {operation, parse(value, type, caller)}
  end

  defp parse({:if, _, [condition, [do: validation]]}, type, caller) do
    {
      :if,
      parse(condition, type, caller),
      parse(validation, type, caller),
      nil
    }
  end

  defp parse(
         {:if, _, [condition, [do: success_validation, else: failure_validation]]},
         type,
         caller
       ) do
    {
      :if,
      parse(condition, type, caller),
      parse(success_validation, type, caller),
      parse(failure_validation, type, caller)
    }
  end

  defp parse(atom, _type, _caller) when atom in @date_types, do: atom
  defp parse(atom, _type, _caller) when is_atom(atom), do: {:field, atom}
end
