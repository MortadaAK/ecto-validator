defmodule EctoValidator.Validator.Checker do
  require Logger
  alias EctoValidator.Validator.Calculator
  alias EctoValidator.Validator.Utils

  def valid?(%Ecto.Changeset{data: %module{}} = changeset, validation) do
    try do
      %{} = information = apply(module, :information, [])
      valid?(changeset, information, validation)
    rescue
      _ -> false
    end
  end

  def valid?(_changeset, _information, validation) when validation in [nil, []], do: true
  def valid?(_changeset, _information, true), do: true
  def valid?(_changeset, _information, false), do: false

  def valid?(
        changeset,
        information,
        {:and, left, right}
      ) do
    valid?(changeset, information, left) and
      valid?(changeset, information, right)
  end

  def valid?(
        changeset,
        information,
        {:or, left, right}
      ) do
    valid?(changeset, information, left) or
      valid?(changeset, information, right)
  end

  def valid?(
        changeset,
        information,
        {operation, {:field, _left_field} = left, right}
      ) do
    {changeset, result} = Calculator.try_to_calculate(changeset, information, left)

    valid?(
      changeset,
      information,
      {operation, result, right}
    )
  end

  def valid?(
        changeset,
        information,
        {operation, left, {:field, _right_field} = right}
      ) do
    {changeset, result} = Calculator.try_to_calculate(changeset, information, right)

    valid?(
      changeset,
      information,
      {operation, left, result}
    )
  end

  def valid?(changeset, information, {:not, {operation, left, right}}) do
    not valid?(changeset, information, {operation, left, right})
  end

  def valid?(changeset, information, {operation, left, right})
      when is_number(right) and is_number(left),
      do:
        valid?(
          changeset,
          information,
          {operation, Utils.cast_decimal(left), Utils.cast_decimal(right)}
        )

  def valid?(changeset, information, {operation, %Decimal{} = left, right}) when is_number(right),
    do: valid?(changeset, information, {operation, left, Utils.cast_decimal(right)})

  def valid?(changeset, information, {operation, left, %Decimal{} = right}) when is_number(left),
    do: valid?(changeset, information, {operation, Utils.cast_decimal(left), right})

  def valid?(_changeset, _information, {operation, %Decimal{} = left, %Decimal{} = right})
      when operation in [:gt, :gteq, :lt, :lteq, :eq, :not_eq] do
    valid?(operation, left, right)
  end

  def valid?(_changeset, _information, {operation, %Date{} = left, %Date{} = right})
      when operation in [:gt, :gteq, :lt, :lteq, :eq, :not_eq] do
    valid?(operation, left, right)
  end

  def valid?(_changeset, _information, {:eq, left, left}), do: true
  def valid?(_changeset, _information, {:eq, _left, _right}), do: false

  def valid?(:gt, left, right), do: Utils.gt?(left, right)
  def valid?(:gteq, left, right), do: Utils.gteq?(left, right)
  def valid?(:lt, left, right), do: Utils.lt?(left, right)
  def valid?(:lteq, left, right), do: Utils.lteq?(left, right)
  def valid?(:eq, left, right), do: Utils.eq?(left, right)
  def valid?(:not_eq, left, right), do: not Utils.eq?(left, right)

  def valid?(_changeset, _information, {operation, left, right})
      when operation in [:gt, :gteq, :lt, :lteq] and (is_nil(left) or is_nil(right)) do
    true
  end

  def valid?(_changeset, _information, validation) do
    Logger.error("SKIPPING validation #{inspect(validation)}")

    false
  end
end
