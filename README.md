# Current setup

```
# Create mlx model from qwen base
./convert-model.sh Qwen/Qwen3.5-35B-A3B Qwen/Qwen3.5-35B-A3B-TEXT-8bit 8 text

# Start deployment with model
./manage-deployments.sh install qwen3.5-35b-a3b-text-8bit --start

# Update opencode with config
# ~/.config/opencode/opencode.json
    "model": "mlx-local/mlx-local",
    "provider": {
        "mlx-local": {
            "npm": "@ai-sdk/openai-compatible",
            "name": "MLX Local Server",
            "options": {
                "baseURL": "http://localhost:8000/v1"
            },
            "models": {
                "mlx-local": {
                    "name": "MLX Local Model"
                }
            }
        }
```

# Qwen3.5

We recommend using the following set of sampling parameters for generation

Thinking mode for general tasks:
* temperature=1.0, top_p=0.95, top_k=20, min_p=0.0, presence_penalty=1.5, repetition_penalty=1.0

Thinking mode for precise coding tasks (e.g. WebDev):
* temperature=0.6, top_p=0.95, top_k=20, min_p=0.0, presence_penalty=0.0, repetition_penalty=1.0

Instruct (or non-thinking) mode for general tasks:
* temperature=0.7, top_p=0.8, top_k=20, min_p=0.0, presence_penalty=1.5, repetition_penalty=1.0

Instruct (or non-thinking) mode for reasoning tasks:
* temperature=1.0, top_p=1.0, top_k=40, min_p=0.0, presence_penalty=2.0, repetition_penalty=1.0

Please note that the support for sampling parameters varies according to inference frameworks.

## Multimodal deployment note

For vision-capable models, set `server.chat_template_args` in your deployment
`config.json`. These values are forwarded to `mlx_lm server --chat-template-args`
by the generated `start.sh` script, and then into tokenizer
`apply_chat_template(...)`.

Example:

```json
{
  "server": {
    "chat_template_args": {
      "add_vision_id": true
    }
  }
}
```
