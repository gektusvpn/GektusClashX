package main

import (
	"encoding/json"
	"fmt"
	"regexp"
	"strings"
)

const coreCompatibilityErrorPrefix = "gektusclashx-core-compatibility:"

var minimumCorePattern = regexp.MustCompile(`(?i)^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$`)
var runningCorePattern = regexp.MustCompile(`(?i)^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z.-]+))?(?:\+([0-9A-Za-z.-]+))?$`)

func checkCoreCompatibility(current, minimum string) error {
	required := minimumCorePattern.FindStringSubmatch(strings.TrimSpace(minimum))
	// Absent and malformed optional requirements do not change existing behavior.
	if required == nil {
		return nil
	}
	live := runningCorePattern.FindStringSubmatch(strings.TrimSpace(current))
	if live != nil {
		for i := 1; i <= 3; i++ {
			if len(live[i]) > len(required[i]) {
				return nil
			}
			if len(live[i]) < len(required[i]) {
				break
			}
			if live[i] > required[i] {
				return nil
			}
			if live[i] < required[i] {
				break
			}
			if i == 3 && live[4] == "" {
				return nil
			}
		}
	}
	data, _ := json.Marshal(struct {
		Minimum string `json:"minimum"`
		Current string `json:"current"`
		Unknown bool   `json:"unknown"`
	}{strings.TrimSpace(minimum), current, live == nil})
	return fmt.Errorf("%s%s", coreCompatibilityErrorPrefix, data)
}
