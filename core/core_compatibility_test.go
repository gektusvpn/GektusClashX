package main

import (
	"encoding/json"
	"os"
	"strings"
	"testing"

	"github.com/metacubex/mihomo/constant"
)

func TestCoreCompatibilitySharedCases(t *testing.T) {
	bytes, err := os.ReadFile("../test/fixtures/core_compatibility.json")
	if err != nil {
		t.Fatal(err)
	}
	var cases []struct {
		Current    string `json:"current"`
		Minimum    string `json:"minimum"`
		Compatible *bool  `json:"compatible"`
	}
	if err = json.Unmarshal(bytes, &cases); err != nil {
		t.Fatal(err)
	}
	for _, c := range cases {
		t.Run(c.Current+">="+c.Minimum, func(t *testing.T) {
			err := checkCoreCompatibility(c.Current, c.Minimum)
			if c.Compatible != nil && *c.Compatible {
				if err != nil {
					t.Fatal(err)
				}
				return
			}
			if err == nil {
				t.Fatal("expected compatibility refusal")
			}
			if !strings.HasPrefix(err.Error(), coreCompatibilityErrorPrefix) {
				t.Fatal(err)
			}
			var failure struct {
				Unknown bool `json:"unknown"`
			}
			if e := json.Unmarshal([]byte(strings.TrimPrefix(err.Error(), coreCompatibilityErrorPrefix)), &failure); e != nil {
				t.Fatal(e)
			}
			if failure.Unknown != (c.Compatible == nil) {
				t.Fatalf("wrong unknown flag: %v", failure.Unknown)
			}
		})
	}
}

func TestSetupRejectsBeforeChangingConfig(t *testing.T) {
	old := constant.Version
	constant.Version = "v1.19.29"
	defer func() { constant.Version = old }()
	// Config is intentionally nil. Rejection must happen before config parsing,
	// timers, or any mutation of the active executor.
	err := setupConfig(&SetupParams{MinCoreVersion: "1.19.30"})
	if err == nil || !strings.HasPrefix(err.Error(), coreCompatibilityErrorPrefix) {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestSetupParamsKeepsRequirementForQuickStart(t *testing.T) {
	var params SetupParams
	if err := json.Unmarshal([]byte(`{"min-core-version":"1.19.30"}`), &params); err != nil {
		t.Fatal(err)
	}
	if params.MinCoreVersion != "1.19.30" {
		t.Fatal("lost minimum core version")
	}
	if err := json.Unmarshal([]byte(`{}`), new(SetupParams)); err != nil {
		t.Fatal(err)
	}
}
