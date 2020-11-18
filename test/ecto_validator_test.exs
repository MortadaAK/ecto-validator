defmodule EctoValidatorTest do
  use ExUnit.Case
  alias EctoValidator.Validator.Utils

  describe "validations" do
    test "should require value" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :string, validations: :required)
        end
      end

      changeset = module |> struct() |> EctoValidator.changeset(%{})
      assert "can't be blank" in errors_on(changeset).field1
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: nil})
      assert "can't be blank" in errors_on(changeset).field1
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: "field"})
      refute changeset |> errors_on() |> Map.has_key?(:field1)
    end

    test "validate minimum length of string" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :string, validations: min(10))
        end
      end

      changeset =
        module |> struct() |> EctoValidator.changeset(%{field1: String.duplicate("a", 9)})

      assert "should be at least 10 character(s)" in errors_on(changeset).field1

      changeset =
        module |> struct() |> EctoValidator.changeset(%{field1: String.duplicate("a", 10)})

      refute changeset |> errors_on() |> Map.has_key?(:field1)
    end

    test "validate maximum length of string" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :string, validations: max(10))
        end
      end

      changeset =
        module |> struct() |> EctoValidator.changeset(%{field1: String.duplicate("a", 11)})

      assert "should be at most 10 character(s)" in errors_on(changeset).field1

      changeset =
        module |> struct() |> EctoValidator.changeset(%{field1: String.duplicate("a", 10)})

      refute changeset |> errors_on() |> Map.has_key?(:field1)
    end

    test "validate string to be in a list" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :string, validations: _ in ~w(1 2 3))
        end
      end

      changeset = module |> struct() |> EctoValidator.changeset(%{field1: "4"})

      assert "is invalid" in errors_on(changeset).field1

      for i <- ~w(1 2 3) do
        changeset = module |> struct() |> EctoValidator.changeset(%{field1: i})

        refute changeset |> errors_on() |> Map.has_key?(:field1)
      end
    end

    test "validate string array to be in a list" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, {:array, :string}, validations: _ in ~w(1 2 3))
        end
      end

      changeset = module |> struct() |> EctoValidator.changeset(%{field1: ["4"]})

      assert "has an invalid entry" in errors_on(changeset).field1

      for i <- ~w(1 2 3) do
        changeset = module |> struct() |> EctoValidator.changeset(%{field1: [i]})

        refute changeset |> errors_on() |> Map.has_key?(:field1)
      end
    end

    test "validate string to be in a list from a function within the module" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :string, validations: _ in :list)
        end

        def list(:field1), do: ~w(1 2 3)
      end

      changeset = module |> struct() |> EctoValidator.changeset(%{field1: "4"})

      assert "is invalid" in errors_on(changeset).field1

      for i <- ~w(1 2 3) do
        changeset = module |> struct() |> EctoValidator.changeset(%{field1: i})

        refute changeset |> errors_on() |> Map.has_key?(:field1)
      end
    end

    test "validate string to be in a list from an external function" do
      module1 = String.to_atom("Test#{random()}")
      module = String.to_atom("Test#{random()}")

      defmodule Module11233 do
        def list(:field1), do: ~w(1 2 3)
      end

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :string, validations: _ in {Module11233, :list})
        end
      end

      changeset = module |> struct() |> EctoValidator.changeset(%{field1: "4"})

      assert "is invalid" in errors_on(changeset).field1

      for i <- ~w(1 2 3) do
        changeset = module |> struct() |> EctoValidator.changeset(%{field1: i})

        refute changeset |> errors_on() |> Map.has_key?(:field1)
      end
    end

    test "validate string to be not in a list" do
      module1 = String.to_atom("Test#{random()}")

      defmodule Module223311 do
        def list(_), do: ~w(1 2 3)
      end

      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :string, validations: _ not in ~w(1 2 3))
          field(:field2, :string, validations: _ not in :list)
          field(:field4, :string, validations: _ not in {Module223311, :list})
        end

        def list(_), do: ~w(1 2 3)
      end

      changeset =
        module |> struct() |> EctoValidator.changeset(%{field1: "4", field2: "4", field3: "4"})

      refute changeset |> errors_on() |> Map.has_key?(:field1)

      for i <- ~w(1 2 3) do
        changeset =
          module |> struct() |> EctoValidator.changeset(%{field1: i, field2: i, field3: i})

        assert "is invalid" in errors_on(changeset).field1
      end
    end

    test "validate string to be a value" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :string, validations: _ == "some string")
        end
      end

      changeset = module |> struct() |> EctoValidator.changeset(%{field1: "other value"})
      assert "is invalid" in errors_on(changeset).field1
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: "some string"})

      refute changeset |> errors_on() |> Map.has_key?(:field1)
    end

    test "validate string to be not a value" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :string, validations: _ != "some string")
        end
      end

      changeset = module |> struct() |> EctoValidator.changeset(%{field1: "some string"})
      assert "is invalid" in errors_on(changeset).field1
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: "other value"})

      refute changeset |> errors_on() |> Map.has_key?(:field1)
    end

    test "validate string using regex" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :string, validations: matches(~r/^[a-f]+$/))
        end
      end

      changeset = module |> struct() |> EctoValidator.changeset(%{field1: "h"})
      assert "has invalid format" in errors_on(changeset).field1
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: "abcdef"})
      refute changeset |> errors_on() |> Map.has_key?(:field1)
    end

    test "validate integer to equal a value" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer, validations: _ == 1)
        end
      end

      changeset = module |> struct() |> EctoValidator.changeset(%{field1: 10})
      assert "must be equal to 1" in errors_on(changeset).field1
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: 1})

      refute changeset |> errors_on() |> Map.has_key?(:field1)
    end

    test "validate integer to be not equal to a value" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer, validations: _ != 1)
        end
      end

      changeset = module |> struct() |> EctoValidator.changeset(%{field1: 10})
      refute changeset |> errors_on() |> Map.has_key?(:field1)
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: 1})
      assert "must be not equal to 1" in errors_on(changeset).field1
    end

    test "validate integer to be greater than a value" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer, validations: _ > 1)
        end
      end

      changeset = module |> struct() |> EctoValidator.changeset(%{field1: 2})
      refute changeset |> errors_on() |> Map.has_key?(:field1)
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: 1})
      assert "must be greater than 1" in errors_on(changeset).field1
    end

    test "validate integer to be greater than or equal to a value" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer, validations: _ >= 1)
        end
      end

      changeset = module |> struct() |> EctoValidator.changeset(%{field1: 2})
      refute changeset |> errors_on() |> Map.has_key?(:field1)
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: 1})
      refute changeset |> errors_on() |> Map.has_key?(:field1)
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: 0})
      assert "must be greater than or equal to 1" in errors_on(changeset).field1
    end

    test "validate integer to be less than a value" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer, validations: _ < 1)
        end
      end

      changeset = module |> struct() |> EctoValidator.changeset(%{field1: 0})
      refute changeset |> errors_on() |> Map.has_key?(:field1)
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: 1})
      assert "must be less than 1" in errors_on(changeset).field1
    end

    test "validate integer to be less than or equal to a value" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer, validations: _ <= 1)
        end
      end

      changeset = module |> struct() |> EctoValidator.changeset(%{field1: 0})
      refute changeset |> errors_on() |> Map.has_key?(:field1)
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: 1})
      refute changeset |> errors_on() |> Map.has_key?(:field1)
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: 2})
      assert "must be less than or equal to 1" in errors_on(changeset).field1
    end

    test "validate decimal to equal a value" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :decimal, validations: _ == Decimal.from_float(1.2))
        end
      end

      changeset = module |> struct() |> EctoValidator.changeset(%{field1: Decimal.new(1)})
      assert "must be equal to 1.2" in errors_on(changeset).field1

      changeset =
        module |> struct() |> EctoValidator.changeset(%{field1: Decimal.from_float(1.2)})

      refute changeset |> errors_on() |> Map.has_key?(:field1)
    end

    test "validate decimal to be not equal to a value" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :decimal, validations: _ != Decimal.from_float(1.2))
        end
      end

      changeset =
        module |> struct() |> EctoValidator.changeset(%{field1: Decimal.from_float(1.3)})

      refute changeset |> errors_on() |> Map.has_key?(:field1)

      changeset =
        module |> struct() |> EctoValidator.changeset(%{field1: Decimal.from_float(1.2)})

      assert "must be not equal to 1.2" in errors_on(changeset).field1
    end

    test "validate decimal to be greater than a value" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :decimal, validations: _ > Decimal.new(1))
        end
      end

      changeset = module |> struct() |> EctoValidator.changeset(%{field1: Decimal.new(2)})
      refute changeset |> errors_on() |> Map.has_key?(:field1)
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: Decimal.new(1)})
      assert "must be greater than 1" in errors_on(changeset).field1
    end

    test "validate decimal to be greater than or equal to a value" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :decimal, validations: _ >= Decimal.new(1))
        end
      end

      changeset = module |> struct() |> EctoValidator.changeset(%{field1: Decimal.new(2)})
      refute changeset |> errors_on() |> Map.has_key?(:field1)
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: Decimal.new(1)})
      refute changeset |> errors_on() |> Map.has_key?(:field1)
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: Decimal.new(0)})
      assert "must be greater than or equal to 1" in errors_on(changeset).field1
    end

    test "validate decimal to be less than a value" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :decimal, validations: _ < Decimal.new(1))
        end
      end

      changeset = module |> struct() |> EctoValidator.changeset(%{field1: Decimal.new(0)})
      refute changeset |> errors_on() |> Map.has_key?(:field1)
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: Decimal.new(1)})
      assert "must be less than 1" in errors_on(changeset).field1
    end

    test "validate decimal to be less than or equal to a value" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :decimal, validations: _ <= Decimal.new(1))
        end
      end

      changeset = module |> struct() |> EctoValidator.changeset(%{field1: Decimal.new(0)})
      refute changeset |> errors_on() |> Map.has_key?(:field1)
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: Decimal.new(1)})
      refute changeset |> errors_on() |> Map.has_key?(:field1)
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: Decimal.new(2)})
      assert "must be less than or equal to 1" in errors_on(changeset).field1
    end

    test "validate decimal array to be in a list" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, {:array, :decimal},
            validations: _ in [Decimal.new("1.2"), Decimal.new("2.2")]
          )

          field(:field2, :decimal, validations: _ in [Decimal.new("1.2"), Decimal.new("2.2")])
        end
      end

      changeset =
        module
        |> struct()
        |> EctoValidator.changeset(%{field1: [Decimal.new(1)], field2: Decimal.new(1)})

      assert "has an invalid entry" in errors_on(changeset).field1
      assert "is invalid" in errors_on(changeset).field2

      for i <- [Decimal.new("1.2"), Decimal.new("2.2")] do
        changeset = module |> struct() |> EctoValidator.changeset(%{field1: [i], field2: i})

        refute changeset |> errors_on() |> Map.has_key?(:field1)
        refute changeset |> errors_on() |> Map.has_key?(:field2)
      end
    end

    test "validate date to be less than date" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :date, validations: _ < :today)
          field(:field2, :date, validations: _ < :beginning_of_month)
          field(:field3, :date, validations: _ < :beginning_of_quarter)
          field(:field4, :date, validations: _ < :beginning_of_year)
          field(:field5, :date, validations: _ < :beginning_of_week)
          field(:field6, :date, validations: _ < :end_of_month)
          field(:field7, :date, validations: _ < :end_of_quarter)
          field(:field8, :date, validations: _ < :end_of_year)
          field(:field9, :date, validations: _ < :end_of_week)
        end
      end

      for {field, target} <- [
            {:field1, :today},
            {:field2, :beginning_of_month},
            {:field3, :beginning_of_quarter},
            {:field4, :beginning_of_year},
            {:field5, :beginning_of_week},
            {:field6, :end_of_month},
            {:field7, :end_of_quarter},
            {:field8, :end_of_year},
            {:field9, :end_of_week}
          ] do
        date = Utils.resolve_date(target)
        changeset = module |> struct() |> EctoValidator.changeset(%{field => date})
        assert ["must be less than" <> _] = errors_on(changeset) |> Map.get(field)

        changeset =
          module
          |> struct()
          |> EctoValidator.changeset(%{field => date |> Timex.shift(days: -1)})

        refute errors_on(changeset) |> Map.has_key?(field)
      end
    end

    test "validate date to be less than or equal to date" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :date, validations: _ <= :today)
          field(:field2, :date, validations: _ <= :beginning_of_month)
          field(:field3, :date, validations: _ <= :beginning_of_quarter)
          field(:field4, :date, validations: _ <= :beginning_of_year)
          field(:field5, :date, validations: _ <= :beginning_of_week)
          field(:field6, :date, validations: _ <= :end_of_month)
          field(:field7, :date, validations: _ <= :end_of_quarter)
          field(:field8, :date, validations: _ <= :end_of_year)
          field(:field9, :date, validations: _ <= :end_of_week)
        end
      end

      for {field, target} <- [
            {:field1, :today},
            {:field2, :beginning_of_month},
            {:field3, :beginning_of_quarter},
            {:field4, :beginning_of_year},
            {:field5, :beginning_of_week},
            {:field6, :end_of_month},
            {:field7, :end_of_quarter},
            {:field8, :end_of_year},
            {:field9, :end_of_week}
          ] do
        date = Utils.resolve_date(target)

        changeset =
          module
          |> struct()
          |> EctoValidator.changeset(%{field => date |> Timex.shift(days: 1)})

        assert ["must be less than" <> _] = errors_on(changeset) |> Map.get(field)

        changeset = module |> struct() |> EctoValidator.changeset(%{field => date})
        refute errors_on(changeset) |> Map.has_key?(field)

        changeset =
          module
          |> struct()
          |> EctoValidator.changeset(%{field => date |> Timex.shift(days: -1)})

        refute errors_on(changeset) |> Map.has_key?(field)
      end
    end

    test "validate date to be greater than date" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :date, validations: _ > :today)
          field(:field2, :date, validations: _ > :beginning_of_month)
          field(:field3, :date, validations: _ > :beginning_of_quarter)
          field(:field4, :date, validations: _ > :beginning_of_year)
          field(:field5, :date, validations: _ > :beginning_of_week)
          field(:field6, :date, validations: _ > :end_of_month)
          field(:field7, :date, validations: _ > :end_of_quarter)
          field(:field8, :date, validations: _ > :end_of_year)
          field(:field9, :date, validations: _ > :end_of_week)
        end
      end

      for {field, target} <- [
            {:field1, :today},
            {:field2, :beginning_of_month},
            {:field3, :beginning_of_quarter},
            {:field4, :beginning_of_year},
            {:field5, :beginning_of_week},
            {:field6, :end_of_month},
            {:field7, :end_of_quarter},
            {:field8, :end_of_year},
            {:field9, :end_of_week}
          ] do
        date = Utils.resolve_date(target)
        changeset = module |> struct() |> EctoValidator.changeset(%{field => date})
        assert ["must be greater than" <> _] = errors_on(changeset) |> Map.get(field)

        changeset =
          module
          |> struct()
          |> EctoValidator.changeset(%{field => date |> Timex.shift(days: 1)})

        refute errors_on(changeset) |> Map.has_key?(field)
      end
    end

    test "validate date to be greater than or equal to date" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :date, validations: _ >= :today)
          field(:field2, :date, validations: _ >= :beginning_of_month)
          field(:field3, :date, validations: _ >= :beginning_of_quarter)
          field(:field4, :date, validations: _ >= :beginning_of_year)
          field(:field5, :date, validations: _ >= :beginning_of_week)
          field(:field6, :date, validations: _ >= :end_of_month)
          field(:field7, :date, validations: _ >= :end_of_quarter)
          field(:field8, :date, validations: _ >= :end_of_year)
          field(:field9, :date, validations: _ >= :end_of_week)
        end
      end

      for {field, target} <- [
            {:field1, :today},
            {:field2, :beginning_of_month},
            {:field3, :beginning_of_quarter},
            {:field4, :beginning_of_year},
            {:field5, :beginning_of_week},
            {:field6, :end_of_month},
            {:field7, :end_of_quarter},
            {:field8, :end_of_year},
            {:field9, :end_of_week}
          ] do
        date = Utils.resolve_date(target)

        changeset =
          module
          |> struct()
          |> EctoValidator.changeset(%{field => date |> Timex.shift(days: -1)})

        assert ["must be greater than" <> _] = errors_on(changeset) |> Map.get(field)

        changeset = module |> struct() |> EctoValidator.changeset(%{field => date})
        refute errors_on(changeset) |> Map.has_key?(field)

        changeset =
          module
          |> struct()
          |> EctoValidator.changeset(%{field => date |> Timex.shift(days: 1)})

        refute errors_on(changeset) |> Map.has_key?(field)
      end
    end

    test "validate date to be equal to date" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :date, validations: _ == :today)
          field(:field2, :date, validations: _ == :beginning_of_month)
          field(:field3, :date, validations: _ == :beginning_of_quarter)
          field(:field4, :date, validations: _ == :beginning_of_year)
          field(:field5, :date, validations: _ == :beginning_of_week)
          field(:field6, :date, validations: _ == :end_of_month)
          field(:field7, :date, validations: _ == :end_of_quarter)
          field(:field8, :date, validations: _ == :end_of_year)
          field(:field9, :date, validations: _ == :end_of_week)
        end
      end

      for {field, target} <- [
            {:field1, :today},
            {:field2, :beginning_of_month},
            {:field3, :beginning_of_quarter},
            {:field4, :beginning_of_year},
            {:field5, :beginning_of_week},
            {:field6, :end_of_month},
            {:field7, :end_of_quarter},
            {:field8, :end_of_year},
            {:field9, :end_of_week}
          ] do
        date = Utils.resolve_date(target)

        changeset =
          module
          |> struct()
          |> EctoValidator.changeset(%{field => date |> Timex.shift(days: -1)})

        assert ["must be equal to" <> _] = errors_on(changeset) |> Map.get(field)

        changeset = module |> struct() |> EctoValidator.changeset(%{field => date})
        refute errors_on(changeset) |> Map.has_key?(field)

        changeset =
          module
          |> struct()
          |> EctoValidator.changeset(%{field => date |> Timex.shift(days: 1)})

        assert ["must be equal to" <> _] = errors_on(changeset) |> Map.get(field)
      end
    end

    test "validate date to be not equal to date" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :date, validations: _ != :today)
          field(:field2, :date, validations: _ != :beginning_of_month)
          field(:field3, :date, validations: _ != :beginning_of_quarter)
          field(:field4, :date, validations: _ != :beginning_of_year)
          field(:field5, :date, validations: _ != :beginning_of_week)
          field(:field6, :date, validations: _ != :end_of_month)
          field(:field7, :date, validations: _ != :end_of_quarter)
          field(:field8, :date, validations: _ != :end_of_year)
          field(:field9, :date, validations: _ != :end_of_week)
        end
      end

      for {field, target} <- [
            {:field1, :today},
            {:field2, :beginning_of_month},
            {:field3, :beginning_of_quarter},
            {:field4, :beginning_of_year},
            {:field5, :beginning_of_week},
            {:field6, :end_of_month},
            {:field7, :end_of_quarter},
            {:field8, :end_of_year},
            {:field9, :end_of_week}
          ] do
        date = Utils.resolve_date(target)

        changeset =
          module
          |> struct()
          |> EctoValidator.changeset(%{field => date |> Timex.shift(days: -1)})

        refute errors_on(changeset) |> Map.has_key?(field)

        changeset = module |> struct() |> EctoValidator.changeset(%{field => date})
        assert ["must be not equal to" <> _] = errors_on(changeset) |> Map.get(field)

        changeset =
          module
          |> struct()
          |> EctoValidator.changeset(%{field => date |> Timex.shift(days: 1)})

        refute errors_on(changeset) |> Map.has_key?(field)
      end
    end

    test "perform and validation" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer, validations: _ >= 1 and _ <= 100)
        end
      end

      changeset = module |> struct() |> EctoValidator.changeset(%{field1: 1})
      refute changeset |> errors_on() |> Map.has_key?(:field1)
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: 100})
      refute changeset |> errors_on() |> Map.has_key?(:field1)
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: 0})
      assert "must be greater than or equal to 1" in errors_on(changeset).field1
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: 101})
      assert "must be less than or equal to 100" in errors_on(changeset).field1
    end

    test "perform or validation" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer, validations: _ == 1 or _ == 100)
        end
      end

      changeset = module |> struct() |> EctoValidator.changeset(%{field1: 1})
      refute changeset |> errors_on() |> Map.has_key?(:field1)
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: 100})
      refute changeset |> errors_on() |> Map.has_key?(:field1)
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: 0})
      assert ["must be equal to 100", "must be equal to 1"] = errors_on(changeset).field1
      changeset = module |> struct() |> EctoValidator.changeset(%{field1: 101})
      assert ["must be equal to 100", "must be equal to 1"] = errors_on(changeset).field1
    end

    test "cast nested modules" do
      defmodule TestNested1 do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer)
        end
      end

      defmodule TestParent1 do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer)
          has_many(:field2, TestNested1, cast: true)
        end
      end

      assert %{
               changes: %{
                 field1: 1,
                 field2: [
                   %{changes: %{field1: 2}},
                   %{changes: %{field1: 3}}
                 ]
               }
             } =
               TestParent1
               |> struct()
               |> EctoValidator.changeset(%{field1: 1, field2: [%{field1: 2}, %{field1: 3}]})
    end

    test "should not cast nested modules if cast value is not present" do
      defmodule TestNested2 do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer)
        end
      end

      defmodule TestParent2 do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer)
          has_many(:field2, TestNested2)
        end
      end

      changes = %{
        field1: 1
      }

      assert %{changes: ^changes} =
               TestParent2
               |> struct()
               |> EctoValidator.changeset(%{field1: 1, field2: [%{field1: 2}, %{field1: 3}]})
    end

    test "validate min max lines" do
      defmodule TestNested3 do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer)
        end
      end

      defmodule TestParent3 do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer)
          has_many(:field2, TestNested3, cast: true, validations: min(1))
          has_many(:field3, TestNested3, cast: true, validations: max(2))
        end
      end

      changeset =
        TestParent3
        |> struct()
        |> EctoValidator.changeset(%{
          field1: 1,
          field2: [],
          field3: [%{field1: 1}, %{field1: 1}, %{field1: 1}]
        })

      assert "should have at least 1 item(s)" in errors_on(changeset).field2
      assert "should have at most 2 item(s)" in errors_on(changeset).field3

      changeset =
        TestParent3
        |> struct()
        |> EctoValidator.changeset(%{
          field1: 1,
          field2: [%{field1: 1}],
          field3: [%{field1: 1}, %{field1: 1}]
        })

      refute changeset |> errors_on() |> Map.has_key?(:field2)
      refute changeset |> errors_on() |> Map.has_key?(:field3)
    end

    test "validate min max lines using relative value" do
      defmodule TestNested4 do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer)
        end
      end

      defmodule TestParent4 do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer)
          has_many(:field2, TestNested4, cast: true, validations: min(:field1))
          has_many(:field3, TestNested4, cast: true, validations: max(:field1))
        end
      end

      changeset =
        TestParent4
        |> struct()
        |> EctoValidator.changeset(%{
          field1: 2,
          field2: [],
          field3: [%{field1: 1}, %{field1: 1}, %{field1: 1}]
        })

      assert "should have at least 2 item(s)" in errors_on(changeset).field2
      assert "should have at most 2 item(s)" in errors_on(changeset).field3

      changeset =
        TestParent4
        |> struct()
        |> EctoValidator.changeset(%{
          field1: 2,
          field2: [%{field1: 1}, %{field1: 1}],
          field3: [%{field1: 1}, %{field1: 1}]
        })

      refute changeset |> errors_on() |> Map.has_key?(:field2)
      refute changeset |> errors_on() |> Map.has_key?(:field3)
    end

    test "validate sum/min/max/avg of a field in each lines" do
      defmodule TestNested5 do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer)
        end
      end

      defmodule TestParent5 do
        use EctoValidator

        schema_with_validations "table_name" do
          has_many(:field1, TestNested5, cast: true, validations: min(:field1, :field1) > 2)
          has_many(:field2, TestNested5, cast: true, validations: max(:field2, :field1) <= 2)
          has_many(:field3, TestNested5, cast: true, validations: sum(:field3, :field1) == 2)
        end
      end

      changeset =
        TestParent5
        |> struct()
        |> EctoValidator.changeset(%{
          field1: [%{field1: 1}],
          field2: [%{field1: 3}],
          field3: [%{field1: 1}, %{field1: 2}]
        })

      assert "must be greater than 2" in errors_on(changeset).field1
      assert "must be less than or equal to 2" in errors_on(changeset).field2
      assert "must be equal to 2" in errors_on(changeset).field3

      changeset =
        TestParent5
        |> struct()
        |> EctoValidator.changeset(%{
          field1: [%{field1: 4}],
          field2: [%{field1: 1}],
          field3: [%{field1: 1}, %{field1: 1}]
        })

      refute changeset |> errors_on() |> Map.has_key?(:field1)
      refute changeset |> errors_on() |> Map.has_key?(:field2)
      refute changeset |> errors_on() |> Map.has_key?(:field3)
    end

    test "should require value conditionally" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer, validations: required)
          field(:field2, :integer, validations: if(:field1 > 10, do: _ == 5, else: _ == 15))
          field(:field3, :integer, validations: if(:field1 > 10, do: _ == 15))
        end
      end

      changeset =
        module |> struct() |> EctoValidator.changeset(%{field1: 15, field2: 15, field3: 5})

      assert "must be equal to 5" in errors_on(changeset).field2
      assert "must be equal to 15" in errors_on(changeset).field3

      changeset =
        module |> struct() |> EctoValidator.changeset(%{field1: 5, field2: 5, field3: 5})

      assert "must be equal to 15" in errors_on(changeset).field2
      refute errors_on(changeset) |> Map.has_key?(:field3)
    end

    test "should add unique index" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer, validations: unique("index_name"))
        end
      end

      changeset = module |> struct() |> EctoValidator.changeset(%{})

      assert [%{constraint: "index_name", type: :unique}] = changeset.constraints
    end

    test "should add check constraint" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer, validations: check("check_constraint_name"))
        end
      end

      changeset = module |> struct() |> EctoValidator.changeset(%{})

      assert [%{constraint: "check_constraint_name", type: :check}] = changeset.constraints
    end

    test "should add assoc constraint" do
      module = String.to_atom("Test#{random()}")

      defmodule OtherModule do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer)
        end
      end

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          belongs_to(:field1, OtherModule, validations: assoc("fkey"))
          belongs_to(:field2, OtherModule, validations: assoc("fkey"), foreign_key: :key_id)
        end
      end

      changeset = module |> struct() |> EctoValidator.changeset(%{})

      assert [
               %{constraint: "fkey", type: :foreign_key, field: :key_id},
               %{constraint: "fkey", type: :foreign_key, field: :field1_id}
             ] = changeset.constraints
    end
  end

  describe "operation" do
    test "should perform + calculation" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer, validations: :required, operation: :field2 + :field3)
          field(:field2, :integer, validations: :required)
          field(:field3, :integer, validations: :required)
          field(:field4, :decimal, validations: :required, operation: :field5 + :field6 + 10)
          field(:field5, :decimal, validations: :required)
          field(:field6, :decimal, validations: :required)
        end
      end

      changes = %{
        field1: 4,
        field2: 1,
        field3: 3,
        field4: Decimal.new("15.0"),
        field5: Decimal.new("1.5"),
        field6: Decimal.new("3.5")
      }

      assert %{changes: ^changes} =
               module
               |> struct()
               |> EctoValidator.changeset(%{
                 field2: 1,
                 field3: 3,
                 field5: Decimal.new("1.5"),
                 field6: Decimal.new("3.5")
               })
    end

    test "should perform - calculation" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer, validations: :required, operation: :field2 - :field3)
          field(:field2, :integer, validations: :required)
          field(:field3, :integer, validations: :required)

          field(:field4, :decimal,
            validations: :required,
            operation: :field5 - :field6 - 10
          )

          field(:field5, :decimal, validations: :required)
          field(:field6, :decimal, validations: :required)
        end
      end

      changes = %{
        field1: -2,
        field2: 1,
        field3: 3,
        field4: Decimal.new("-12.0"),
        field5: Decimal.new("1.5"),
        field6: Decimal.new("3.5")
      }

      assert %{changes: ^changes} =
               module
               |> struct()
               |> EctoValidator.changeset(%{
                 field2: 1,
                 field3: 3,
                 field5: Decimal.new("1.5"),
                 field6: Decimal.new("3.5")
               })
    end

    test "should perform * calculation" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer, validations: :required, operation: :field2 * :field3)
          field(:field2, :integer, validations: :required)
          field(:field3, :integer, validations: :required)
          field(:field4, :decimal, validations: :required, operation: :field5 * :field6 * 10)
          field(:field5, :decimal, validations: :required)
          field(:field6, :decimal, validations: :required)
        end
      end

      changes = %{
        field1: 3,
        field2: 1,
        field3: 3,
        field4: Decimal.new("52.50"),
        field5: Decimal.new("1.5"),
        field6: Decimal.new("3.5")
      }

      assert %{changes: ^changes} =
               module
               |> struct()
               |> EctoValidator.changeset(%{
                 field2: 1,
                 field3: 3,
                 field5: Decimal.new("1.5"),
                 field6: Decimal.new("3.5")
               })
    end

    test "should perform / calculation" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer, validations: :required, operation: :field2 / :field3)
          field(:field2, :integer, validations: :required)
          field(:field3, :integer, validations: :required)
          field(:field4, :decimal, validations: :required, operation: :field5 / :field6 / 10)
          field(:field5, :decimal, validations: :required)
          field(:field6, :decimal, validations: :required)
        end
      end

      changes = %{
        field1: 3.0,
        field2: 6,
        field3: 2,
        field4: Decimal.new("3"),
        field5: Decimal.new("60"),
        field6: Decimal.new("2")
      }

      assert %{changes: ^changes} =
               module
               |> struct()
               |> EctoValidator.changeset(%{
                 field2: 6,
                 field3: 2,
                 field5: Decimal.new("60"),
                 field6: Decimal.new("2")
               })
    end

    test "should perform pow calculation" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer, validations: :required, operation: pow(:field2, :field3))
          field(:field2, :integer, validations: :required)
          field(:field3, :integer, validations: :required)
          field(:field4, :decimal, validations: :required, operation: pow(:field5, :field6))
          field(:field5, :decimal, validations: :required)
          field(:field6, :decimal, validations: :required)
        end
      end

      changes = %{
        field1: 36.0,
        field2: 6,
        field3: 2,
        field4: Decimal.new("36.0"),
        field5: Decimal.new("6"),
        field6: Decimal.new("2")
      }

      assert %{changes: ^changes} =
               module
               |> struct()
               |> EctoValidator.changeset(%{
                 field2: 6,
                 field3: 2,
                 field5: Decimal.new("6"),
                 field6: Decimal.new("2")
               })
    end

    test "should add to a date" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :date)
          field(:field2, :date, operation: :field1 + days(1))
          field(:field3, :date, operation: :field1 + weeks(1))
          field(:field4, :date, operation: :field1 + months(1))
          field(:field5, :date, operation: :field1 + years(1))
        end
      end

      date1 = ~D[2020-01-01]
      date2 = ~D[2020-01-02]
      date3 = ~D[2020-01-08]
      date4 = ~D[2020-02-01]
      date5 = ~D[2021-01-01]

      assert %{
               changes: %{
                 field1: ^date1,
                 field2: ^date2,
                 field3: ^date3,
                 field4: ^date4,
                 field5: ^date5
               }
             } =
               module
               |> struct()
               |> EctoValidator.changeset(%{
                 field1: date1
               })
    end

    test "should subtract from a date" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :date)
          field(:field2, :date, operation: :field1 - days(1))
          field(:field3, :date, operation: :field1 - weeks(1))
          field(:field4, :date, operation: :field1 - months(1))
          field(:field5, :date, operation: :field1 - years(1))
        end
      end

      date1 = ~D[2020-01-01]
      date2 = ~D[2019-12-31]
      date3 = ~D[2019-12-25]
      date4 = ~D[2019-12-01]
      date5 = ~D[2019-01-01]

      assert %{
               changes: %{
                 field1: ^date1,
                 field2: ^date2,
                 field3: ^date3,
                 field4: ^date4,
                 field5: ^date5
               }
             } =
               module
               |> struct()
               |> EctoValidator.changeset(%{
                 field1: date1
               })
    end

    test "should perform date calculation from relative field" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :date)
          field(:field2, :integer)
          field(:field3, :date, operation: :field1 + days(:field2))
          field(:field4, :date, operation: :field1 - days(:field2))
        end
      end

      date1 = ~D[2020-01-01]
      date3 = ~D[2020-01-02]
      date4 = ~D[2019-12-31]

      assert %{
               changes: %{
                 field1: ^date1,
                 field2: 1,
                 field3: ^date3,
                 field4: ^date4
               }
             } =
               module
               |> struct()
               |> EctoValidator.changeset(%{
                 field1: date1,
                 field2: 1
               })
    end

    test "should perform multiple date calculation" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :date)
          field(:field2, :integer)

          field(:field3, :date,
            operation: :field1 + days(:field2) + months(:field2) - years(:field2)
          )
        end
      end

      date1 = ~D[2020-01-01]
      date3 = ~D[2019-02-02]

      assert %{
               changes: %{
                 field1: ^date1,
                 field2: 1,
                 field3: ^date3
               }
             } =
               module
               |> struct()
               |> EctoValidator.changeset(%{
                 field1: date1,
                 field2: 1
               })
    end

    test "calculate min/max/sum of nested records" do
      defmodule TestNested15 do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer)
        end
      end

      defmodule TestParent15 do
        use EctoValidator

        schema_with_validations "table_name" do
          has_many(:field1, TestNested15, cast: true)
          has_many(:field2, TestNested15, cast: true)
          has_many(:field3, TestNested15, cast: true)
          field(:field4, :integer, operation: min(:field1, :field1))
          field(:field5, :integer, operation: max(:field2, :field1))
          field(:field6, :integer, operation: sum(:field3, :field1))
          field(:field7, :integer, operation: :field4 + sum(:field3, :field1))
          field(:field8, :integer, operation: max(:field2, :field1) - min(:field1, :field1))
        end
      end

      field4 = Decimal.new(1)
      field5 = Decimal.new(3)
      field6 = Decimal.new(4)
      field7 = Decimal.new(5)
      field8 = Decimal.new(2)

      assert %{
               changes: %{
                 field4: ^field4,
                 field5: ^field5,
                 field6: ^field6,
                 field7: ^field7,
                 field8: ^field8
               }
             } =
               TestParent15
               |> struct()
               |> EctoValidator.changeset(%{
                 field1: [%{field1: 1}, %{field1: 3}],
                 field2: [%{field1: 1}, %{field1: 3}],
                 field3: [%{field1: 1}, %{field1: 3}]
               })
    end

    test "boolean calculation" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :integer, validations: :required)
          field(:field2, :integer, validations: :required)

          field(:field3, :boolean,
            operation: :field1 == :field2 and (:field1 == 1 or :field2 == 2)
          )
        end
      end

      assert %{
               changes: %{
                 field1: 1,
                 field2: 1,
                 field3: true
               }
             } =
               module
               |> struct()
               |> EctoValidator.changeset(%{
                 field1: 1,
                 field2: 1
               })

      assert %{
               changes: %{
                 field1: 2,
                 field2: 2,
                 field3: true
               }
             } =
               module
               |> struct()
               |> EctoValidator.changeset(%{
                 field1: 2,
                 field2: 2
               })
    end

    test "should raise an error for cycled referencing (simple)" do
      assert_raise(RuntimeError, "field2 has cycle dependency on field1", fn ->
        module = String.to_atom("Test#{random()}")

        defmodule module do
          use EctoValidator

          schema_with_validations "table_name" do
            field(:field1, :integer, operation: :field2 + 1)
            field(:field2, :integer, operation: :field1 + 1)
          end
        end
      end)
    end

    test "should raise an error for cycled referencing (deep)" do
      assert_raise(RuntimeError, "field4 has cycle dependency on field1", fn ->
        module = String.to_atom("Test#{random()}")

        defmodule module do
          use EctoValidator

          schema_with_validations "table_name" do
            field(:field1, :integer, operation: :field2 + 1)
            field(:field2, :integer, operation: :field3 + 1)
            field(:field3, :integer, operation: :field4 + 1)
            field(:field4, :integer, operation: :field1 + 1)
          end
        end
      end)
    end
  end

  describe "default" do
    test "should initialize dates" do
      module = String.to_atom("Test#{random()}")

      defmodule module do
        use EctoValidator

        schema_with_validations "table_name" do
          field(:field1, :date, default: :today)
          field(:field2, :date, default: :beginning_of_month)
          field(:field3, :date, default: :beginning_of_quarter)
          field(:field4, :date, default: :beginning_of_year)
          field(:field5, :date, default: :beginning_of_week)
          field(:field6, :date, default: :end_of_month)
          field(:field7, :date, default: :end_of_quarter)
          field(:field8, :date, default: :end_of_year)
          field(:field9, :date, default: :end_of_week)
        end
      end

      assert %{changes: changes} = module |> struct() |> EctoValidator.changeset()
      assert changes.field1 == Utils.resolve_date(:today)
      assert changes.field2 == Utils.resolve_date(:beginning_of_month)
      assert changes.field3 == Utils.resolve_date(:beginning_of_quarter)
      assert changes.field4 == Utils.resolve_date(:beginning_of_year)
      assert changes.field5 == Utils.resolve_date(:beginning_of_week)
      assert changes.field6 == Utils.resolve_date(:end_of_month)
      assert changes.field7 == Utils.resolve_date(:end_of_quarter)
      assert changes.field8 == Utils.resolve_date(:end_of_year)
      assert changes.field9 == Utils.resolve_date(:end_of_week)
    end
  end

  def random(), do: System.unique_integer([:positive])

  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
