{ config, lib, pkgs, ... }:

{
  programs.opencode = {
    enable = true;
    settings = {
      # Default model configuration (Claude Sonnet 4)
      model = "claude-sonnet-4";
      small_model = "o4-mini";
      
      # Optional: Temperature setting for responses
      temperature = 0.7;
      
      # Optional: Maximum tokens for responses
      maxTokens = 4096;
      
      # Optional: Enable/disable features
      autoComplete = true;
      syntaxHighlighting = true;

      # Gruvbox theme
      theme = "gruvbox";

      # Optional: Editor integration
      editor = {
        defaultEditor = "emacs";
        autoOpen = false;
      };
      
      # Optional: Logging configuration
      logging = {
        level = "info";
        file = "$HOME/.local/share/opencode/opencode.log";
      };
      
      # Optional: Cache settings
      cache = {
        enabled = true;
        directory = "$HOME/.cache/opencode";
        maxSize = "1GB";
      };
      
      # Configure GitHub provider with multiple models
      provider = {
        github = {
          models = {
            # Small/fast model for quick responses
            "gpt-4o-mini" = {
              name = "GPT-4o Mini (Small)";
              options = {
                maxTokens = 2048;
                temperature = 0.5;
              };
            };
            # Normal model for comprehensive responses  
            "claude-sonnet-4" = {
              name = "Claude Sonnet 4 (Normal)";
              options = {
                maxTokens = 4096;
                temperature = 0.7;
              };
            };
          };
        };
      };
    };
  };
}