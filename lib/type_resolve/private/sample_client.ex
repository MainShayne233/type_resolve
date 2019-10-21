defmodule TypeResolve.Private.SupportingModule do
  @type t :: binary()
end

defmodule TypeResolve.Private.SampleClient do
  alias TypeResolve.Private.SupportingModule, as: Support

  @type status :: :pending | :success | :failure

  @type t :: status()

  @type support :: Support.t()

  @type union :: Support.t() | t()

  @type result :: {:ok, term()} | :error

  @type result(t) :: {:ok, t} | :error

  @typep pemail :: binary()

  @type email :: pemail()
end
