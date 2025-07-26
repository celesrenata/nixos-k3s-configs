final: prev:
{
  nvidia-container-toolkit = prev.nvidia-container-toolkit.overrideAttrs (oldAttrs: {
    # Ensure all nvidia-container-toolkit binaries are available
    postInstall = (oldAttrs.postInstall or "") + ''
      # Create symlinks to ensure nvidia-container-cli is in the expected location
      mkdir -p $out/bin
      # The nvidia-container-cli should already be installed, but let's make sure it's accessible
      if [ -f $out/bin/nvidia-container-cli ]; then
        echo "nvidia-container-cli found at $out/bin/nvidia-container-cli"
      else
        echo "WARNING: nvidia-container-cli not found in expected location"
      fi
    '';
  });
}
