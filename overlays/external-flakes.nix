inputs: self: super:

{
  deskrun = inputs.deskrun.packages.${super.system}.default;
}