package main

import (
	"testing"

	"github.com/metacubex/mihomo/config"
)

func TestProxyDescriptionAliases(t *testing.T) {
	for _, tc := range []struct {
		name   string
		fields map[string]interface{}
		want   string
	}{
		{"description is not a server field", map[string]interface{}{"description": "Для видео"}, ""},
		{"camel case", map[string]interface{}{"serverDescription": "Legacy"}, "Legacy"},
		{"hyphenated", map[string]interface{}{"server-description": "Legacy"}, "Legacy"},
		{"priority", map[string]interface{}{"serverDescription": "First", "server-description": "Second", "description": "Third"}, "First"},
		{"blank fallback", map[string]interface{}{"serverDescription": "  ", "server-description": " Custom "}, "Custom"},
		{"invalid fallback", map[string]interface{}{"serverDescription": 123, "server-description": "Custom"}, "Custom"},
		{"blank", map[string]interface{}{"serverDescription": " \n "}, ""},
		{"missing", map[string]interface{}{}, ""},
	} {
		t.Run(tc.name, func(t *testing.T) {
			tc.fields["name"] = "Germany"
			extractProxyDescriptionsFromRaw(&config.RawConfig{Proxy: []map[string]interface{}{tc.fields}})
			if got := proxyDescriptions["Germany"]; got != tc.want {
				t.Fatalf("got %q, want %q", got, tc.want)
			}
		})
	}
}

func TestProxyDescriptionsResetWithConfig(t *testing.T) {
	for _, next := range []*config.RawConfig{nil, {}, {Proxy: []map[string]interface{}{{"name": "Germany"}}}} {
		extractProxyDescriptionsFromRaw(&config.RawConfig{Proxy: []map[string]interface{}{{"name": "Germany", "serverDescription": "Old"}}})
		extractProxyDescriptionsFromRaw(next)
		if len(proxyDescriptions) != 0 {
			t.Fatalf("stale descriptions: %v", proxyDescriptions)
		}
	}
}

func TestProxyDescriptionSurvivesYAMLParsing(t *testing.T) {
	raw, err := config.UnmarshalRawConfig([]byte(`
proxies:
  - name: Germany
    type: vless
    server: example.com
    port: 443
    uuid: 00000000-0000-0000-0000-000000000001
    serverDescription: Для видео
`))
	if err != nil {
		t.Fatal(err)
	}
	extractProxyDescriptionsFromRaw(raw)
	if got := proxyDescriptions["Germany"]; got != "Для видео" {
		t.Fatalf("description lost while parsing YAML: %q", got)
	}
}
