defmodule EctoValidator.Validator.Runner do
  alias Ecto.Changeset
  alias EctoValidator.Validator.{Utils, Checker, Calculator}
  alias EctoValidator.Validator.Utils, as: BuilderUtils
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

  def validate_fields(changeset, information, fields) do
    Enum.reduce(fields, changeset, fn field, changeset ->
      validate_field(
        changeset,
        field,
        information,
        Map.get(information.validations, field),
        Map.get(information.types, field)
      )
    end)
  end

  # there is nothing to validate
  def validate_field(changeset, _field, _information, validations, _type)
      when validations in [nil, []],
      do: changeset

  def validate_field(changeset, field, information, {:not, {:not, validation}}, type),
    do: validate_field(changeset, field, information, validation, type)

  def validate_field(changeset, field, information, {:not, {operation, :self, validation}}, type),
    do: validate_field(changeset, field, information, {:not, {operation, validation}}, type)

  def validate_field(changeset, field, information, {operation, :self, validations}, type),
    do: validate_field(changeset, field, information, {operation, validations}, type)

  def validate_field(changeset, field, _information, {:unique, name}, _) do
    Changeset.unique_constraint(changeset, field, name: name)
  end

  def validate_field(changeset, field, _information, {:check, name}, _) do
    Changeset.check_constraint(changeset, field, name: name)
  end

  def validate_field(changeset, field, _information, {:assoc, name}, _) do
    Changeset.assoc_constraint(changeset, field, name: name)
  end

  def validate_field(changeset, field, _information, {:controlled, {module, func}}, _) do
    try do
      cond do
        function_exported?(module, func, 1) ->
          apply(module, func, [changeset])

        function_exported?(module, func, 2) ->
          apply(module, func, [changeset, field])

        true ->
          Logger.warn("missing controller function #{module}.#{func}/1 or #{module}.#{func}/2")
          changeset
      end
    rescue
      _ -> changeset
    end
  end

  def validate_field(
        %Changeset{data: %module{}} = changeset,
        field,
        _information,
        {:controlled, func},
        _
      ) do
    try do
      cond do
        function_exported?(module, func, 1) ->
          apply(module, func, [changeset])

        function_exported?(module, func, 2) ->
          apply(module, func, [changeset, field])

        true ->
          Logger.warn("missing controller function #{func}/1 or #{func}/2")
          changeset
      end
    rescue
      _ -> changeset
    end
  end

  def validate_field(
        changeset,
        _field,
        _information,
        {:controlled, func},
        _
      ) do
    Logger.warn("skipping controller #{inspect(func)}")
    changeset
  end

  def validate_field(changeset, _field, _information, {type, nil}, _)
      when type in [:min, :max, :sum],
      do: changeset

  # nested validations
  def validate_field(
        changeset,
        field,
        information,
        {operation, {:field, field_name}},
        type
      )
      when operation in [:min, :max, :sum] do
    changeset = BuilderUtils.ensure_variable(changeset, information, field_name)

    validate_field(
      changeset,
      field,
      information,
      {operation, Changeset.get_field(changeset, field_name)},
      type
    )
  end

  def validate_field(changeset, field, _information, {:min, min}, _type)
      when is_number(min) and min > 0 do
    changeset
    |> Changeset.validate_length(field, min: min)
    |> Changeset.validate_required([field])
  end

  def validate_field(changeset, field, _information, {:max, max}, _type)
      when is_number(max) do
    Changeset.validate_length(changeset, field, max: max)
  end

  def validate_field(
        changeset,
        field,
        information,
        {operation, value, date_type},
        type
      )
      when date_type in @date_types do
    date = Utils.resolve_date(date_type)

    validate_field(
      changeset,
      field,
      information,
      {operation, value, date},
      type
    )
  end

  def validate_field(
        changeset,
        field,
        information,
        {operation, date_type, value},
        type
      )
      when date_type in @date_types do
    date = Utils.resolve_date(date_type)

    validate_field(
      changeset,
      field,
      information,
      {operation, date, value},
      type
    )
  end

  def validate_field(
        changeset,
        field,
        information,
        {operation, value, {:field, field_name}},
        type
      ) do
    changeset = BuilderUtils.ensure_variable(changeset, information, field_name)

    validate_field(
      changeset,
      field,
      information,
      {operation, value, Changeset.get_field(changeset, field_name)},
      type
    )
  end

  def validate_field(
        changeset,
        field,
        information,
        {operation, {:field, field_name}, value},
        type
      ) do
    changeset = BuilderUtils.ensure_variable(changeset, information, field_name)

    validate_field(
      changeset,
      field,
      information,
      {operation, Changeset.get_field(changeset, field_name), value},
      type
    )
  end

  # calculates the sum of a field in the nested
  def validate_field(
        changeset,
        field,
        _information,
        {operation, {:sum, field_name, nested_field_name}, value},
        _type
      ) do
    sum = BuilderUtils.calculate_aggregate_value(changeset, field_name, nested_field_name, :add)

    validate_nested_value(changeset, field, operation, value, sum)
  end

  # calculates the min of a field in the nested
  def validate_field(
        changeset,
        field,
        _information,
        {operation, {:min, field_name, nested_field_name}, value},
        _type
      ) do
    min = BuilderUtils.calculate_aggregate_value(changeset, field_name, nested_field_name, :min)

    validate_nested_value(changeset, field, operation, value, min)
  end

  # calculates the max of a field in the nested
  def validate_field(
        changeset,
        field,
        _information,
        {operation, {:max, field_name, nested_field_name}, value},
        _type
      ) do
    max = BuilderUtils.calculate_aggregate_value(changeset, field_name, nested_field_name, :max)

    validate_nested_value(changeset, field, operation, value, max)
  end

  def validate_field(
        changeset,
        field,
        information,
        {operation, {calc_operation, left, right}},
        type
      )
      when calc_operation in [:add, :subtr, :mult, :divd, :pow] do
    {changeset, result} =
      Calculator.try_to_calculate(changeset, information, {calc_operation, left, right})

    validate_field(
      changeset,
      field,
      information,
      {operation, result},
      type
    )
  end

  def validate_field(
        changeset,
        field,
        information,
        {operation, {calc_operation, field_name}},
        type
      )
      when calc_operation in [:sum, :min, :max] do
    {changeset, result} =
      Calculator.try_to_calculate(changeset, information, {calc_operation, field_name})

    validate_field(
      changeset,
      field,
      information,
      {operation, result},
      type
    )
  end

  # merge changesets (and)
  def validate_field(
        changeset,
        field,
        information,
        {:and, left, right},
        type
      ) do
    changeset
    |> validate_field(field, information, left, type)
    |> validate_field(field, information, right, type)
  end

  # choose a valid changesets (or)
  def validate_field(
        changeset,
        field,
        information,
        {:or, left, right},
        type
      ) do
    left_changeset = validate_field(changeset, field, information, left, type)

    right_changeset = validate_field(changeset, field, information, right, type)

    left_errors = Keyword.get_values(left_changeset.errors, field)
    right_errors = Keyword.get_values(right_changeset.errors, field)

    case {left_errors, right_errors} do
      {[], _} ->
        changeset

      {_, []} ->
        changeset

      _errors ->
        (left_errors ++ right_errors)
        |> Enum.reduce(changeset, fn {message, opt}, changeset ->
          Changeset.add_error(changeset, field, message, opt)
        end)
    end
  end

  # reverse not <
  def validate_field(changeset, field, information, {:not, {:lt, value}}, type),
    do: validate_field(changeset, field, information, {:gteq, value}, type)

  # reverse not <=
  def validate_field(changeset, field, information, {:not, {:lteq, value}}, type),
    do: validate_field(changeset, field, information, {:gt, value}, type)

  # reverse not >
  def validate_field(changeset, field, information, {:not, {:gt, value}}, type),
    do: validate_field(changeset, field, information, {:lteq, value}, type)

  # reverse not >=
  def validate_field(changeset, field, information, {:not, {:gteq, value}}, type),
    do: validate_field(changeset, field, information, {:lt, value}, type)

  # validate numeric !=
  def validate_field(changeset, field, information, {:not, {:eq, value}}, type)
      when type in [:integer, :decimal] do
    validate_field(changeset, field, information, {:not_eq, value}, type)
  end

  # validate numeric < <= > >= ==
  def validate_field(changeset, field, _information, {operation, value}, type)
      when type in [:integer, :decimal] and
             operation in [:gt, :gteq, :lt, :lteq, :eq, :not_eq] do
    if is_nil(value) do
      changeset
    else
      opts =
        case operation do
          :gt -> [greater_than: value]
          :gteq -> [greater_than_or_equal_to: value]
          :lt -> [less_than: value]
          :lteq -> [less_than_or_equal_to: value]
          :eq -> [equal_to: value]
          :not_eq -> [not_equal_to: value]
        end

      Changeset.validate_number(changeset, field, opts)
    end
  end

  def validate_field(changeset, field, information, {:not, {:eq, target}}, type)
      when type in [:date],
      do: validate_field(changeset, field, information, {:not_eq, target}, type)

  def validate_field(changeset, field, information, {operation, target}, type)
      when type in [:date] and
             operation in [:gt, :gteq, :lt, :lteq, :eq, :not_eq] do
    {changeset, target_value} = Calculator.try_to_calculate(changeset, information, target)

    with %Date{} <- target_value,
         %Date{} = value <- Changeset.get_field(changeset, field),
         false <-
           Checker.valid?(
             changeset,
             information,
             {operation, value, target_value}
           ) do
      message =
        case operation do
          :gt -> "must be greater than %{date}"
          :gteq -> "must be greater than or equal to %{date}"
          :lt -> "must be less than %{date}"
          :lteq -> "must be less than or equal to %{date}"
          :eq -> "must be equal to %{date}"
          :not_eq -> "must be not equal to %{date}"
        end

      Changeset.add_error(changeset, field, message, date: target_value)
    else
      _ -> changeset
    end
  end

  # validate numeric in
  def validate_field(changeset, field, _information, {:in, list}, type)
      when type in [:decimal, :integer] do
    with value = %Decimal{} <- Changeset.get_field(changeset, field) |> Utils.cast_decimal(),
         false <- Enum.any?(list, &Decimal.eq?(value, &1)) do
      Changeset.add_error(
        changeset,
        field,
        "is invalid",
        validation: :inclusion,
        enum: list
      )
    else
      _ -> changeset
    end
  end

  def validate_field(changeset, field, _information, {:in, list}, {:array, type})
      when type in [:decimal, :integer] do
    with [_ | _] = value <- Changeset.get_field(changeset, field) do
      Enum.reduce_while(value, changeset, fn value, changeset ->
        if Enum.any?(list, &Decimal.eq?(value, &1)) do
          {:cont, changeset}
        else
          {:halt,
           Changeset.add_error(
             changeset,
             field,
             "has an invalid entry",
             validation: :inclusion,
             enum: list
           )}
        end
      end)
    else
      _ -> changeset
    end
  end

  # validate string in
  def validate_field(changeset, field, _information, {:in, value}, {:array, _}) do
    options = Utils.resolve_options(changeset.data, field, value)
    Changeset.validate_subset(changeset, field, options)
  end

  def validate_field(changeset, field, _information, {:in, value}, _type) do
    options = Utils.resolve_options(changeset.data, field, value)
    Changeset.validate_inclusion(changeset, field, options)
  end

  # validate string regex
  def validate_field(changeset, field, _information, {:matches, regex}, _type) do
    Changeset.validate_format(changeset, field, regex)
  end

  # validate !=
  def validate_field(changeset, field, _information, {:not, {:eq, value}}, _type) do
    if Changeset.get_field(changeset, field) == value do
      Changeset.add_error(changeset, field, "is invalid")
    else
      changeset
    end
  end

  # validate ==
  def validate_field(changeset, field, _information, {:eq, value}, _type) do
    Changeset.validate_inclusion(changeset, field, [value])
  end

  # validate required

  def validate_field(changeset, field, _information, :required, _type) do
    Changeset.validate_required(changeset, [field])
  end

  # conditional_validation
  def validate_field(
        changeset,
        field,
        information,
        {:if, condition, success_validations, failure_validation},
        type
      ) do
    if Checker.valid?(changeset, information, condition) do
      validate_field(changeset, field, information, success_validations, type)
    else
      validate_field(changeset, field, information, failure_validation, type)
    end
  end

  def validate_field(changeset, field, information, {:not, validations}, type) do
    new_changeset = validate_field(changeset, field, information, validations, type)

    if Keyword.get(new_changeset.errors, field) do
      changeset
    else
      Changeset.add_error(changeset, field, "is invalid")
    end
  end

  defp validate_nested_value(changeset, field, operation, value, target) do
    valid =
      case operation do
        :gt -> Decimal.gt?(target, value)
        :gteq -> Decimal.gt?(target, value) or Decimal.eq?(target, value)
        :lt -> Decimal.lt?(target, value)
        :lteq -> Decimal.lt?(target, value) or Decimal.eq?(target, value)
        :eq -> Decimal.eq?(target, value)
      end

    {message, opts} = nested_message(operation, value)

    if valid do
      changeset
    else
      Changeset.add_error(changeset, field, message, opts)
    end
  end

  defp nested_message(:gt, value),
    do:
      {"must be greater than %{number}",
       [validation: :number, kind: :greater_than, number: value]}

  defp nested_message(:gteq, value),
    do:
      {"must be greater than or equal to %{number}",
       [validation: :number, kind: :greater_than_or_equal_to, number: value]}

  defp nested_message(:lt, value),
    do: {"must be less than %{number}", [validation: :number, kind: :less_than, number: value]}

  defp nested_message(:lteq, value),
    do:
      {"must be less than or equal to %{number}",
       [validation: :number, kind: :less_than_or_equal_to, number: value]}

  defp nested_message(:eq, value),
    do: {"must be equal to %{number}", [validation: :number, kind: :equal_to, number: value]}
end
