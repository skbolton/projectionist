defmodule Projectionist.Reader.Read do
  @moduledoc """
  Defines parameters for how a stream should be read
  """

  @typedoc """
  Position specifies where in a given stream the caller would like to read from.

    * `:FIRST` - read from first event onward
    * `:LAST` - read last event only
    * `{:after, version}` - read all values after `t:Projectionist.version/0`
    * `{:before, version}` - read all values before `t:Projectionist.version/0`
  """
  @type position ::
          :FIRST | :LAST | {:after, Projectionist.version()} | {:before, Projectionist.version()}

  @typedoc """
  Only pass one of either until or through. Until will filter to all events before the given
  versioning key, excluding the given key. Through filters to all events before or on the
  given versioning key.
  """
  @type t :: %__MODULE__{
          id: term(),
          position: position(),
          count: non_neg_integer() | :infinity,
          until: Projectionist.version() | nil,
          through: Projectionist.version() | nil
        }

  @enforce_keys [:id, :position, :count]
  defstruct [:id, :position, :count, :until, :through]

  def new(opts), do: struct!(__MODULE__, opts)
end
