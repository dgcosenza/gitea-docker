package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

var hexEscapeRe = regexp.MustCompile(`_0[xX]([0-9a-fA-F]{2})_`)

func decodeName(s string) string {
	return hexEscapeRe.ReplaceAllStringFunc(s, func(m string) string {
		sub := hexEscapeRe.FindStringSubmatch(m)
		if len(sub) != 2 {
			return m
		}
		v, err := strconv.ParseUint(sub[1], 16, 8)
		if err != nil {
			return m
		}
		return string([]byte{byte(v)})
	})
}

type kv struct {
	key string
	val string
}

func main() {
	cfgPath := flag.String("config", "/data/gitea/conf/app.ini", "path to app.ini")
	flag.Parse()

	// Parse GITEA__SECTION__KEY and GITEA__SECTION__KEY__FILE env vars
	updates := map[string]map[string]string{}
	for _, entry := range os.Environ() {
		parts := strings.SplitN(entry, "=", 2)
		if len(parts) != 2 {
			continue
		}
		envKey, envVal := parts[0], parts[1]
		if !strings.HasPrefix(envKey, "GITEA__") {
			continue
		}
		rest := strings.TrimPrefix(envKey, "GITEA__")
		segs := strings.Split(rest, "__")
		if len(segs) < 2 {
			continue
		}
		isFile := false
		if segs[len(segs)-1] == "FILE" && len(segs) >= 3 {
			isFile = true
			segs = segs[:len(segs)-1]
		}
		var section, key string
		if len(segs) == 2 {
			section = decodeName(segs[0])
			key = decodeName(segs[1])
		} else {
			section = decodeName(strings.Join(segs[:len(segs)-1], "."))
			key = decodeName(segs[len(segs)-1])
		}
		val := envVal
		if isFile {
			b, err := os.ReadFile(envVal)
			if err != nil {
				fmt.Fprintf(os.Stderr, "environment-to-ini: failed to read %s for %s: %v\n", envVal, envKey, err)
				os.Exit(1)
			}
			val = strings.TrimRight(string(b), "\r\n")
		}
		if updates[section] == nil {
			updates[section] = map[string]string{}
		}
		updates[section][key] = val
	}

	if len(updates) == 0 {
		return
	}

	// Read existing INI lines preserving order & comments
	var lines []string
	if f, err := os.Open(*cfgPath); err == nil {
		sc := bufio.NewScanner(f)
		for sc.Scan() {
			lines = append(lines, sc.Text())
		}
		f.Close()
	}

	// Track sections and keys found in existing file
	applied := map[string]map[string]bool{}
	for sec := range updates {
		applied[sec] = map[string]bool{}
	}

	// First pass: update existing keys in matching sections
	type secBlock struct {
		name  string
		lines []string
	}
	var blocks []secBlock
	cur := secBlock{name: ""}
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "[") && strings.HasSuffix(trimmed, "]") {
			blocks = append(blocks, cur)
			cur = secBlock{name: strings.TrimSpace(trimmed[1 : len(trimmed)-1]), lines: []string{line}}
			continue
		}
		if idx := strings.Index(line, "="); idx > 0 && !strings.HasPrefix(trimmed, ";") && !strings.HasPrefix(trimmed, "#") {
			k := strings.TrimSpace(line[:idx])
			if secMap, ok := updates[cur.name]; ok {
				for uk, uv := range secMap {
					if strings.EqualFold(uk, k) {
						line = fmt.Sprintf("%s = %s", uk, uv)
						applied[cur.name][uk] = true
						break
					}
				}
			}
		}
		cur.lines = append(cur.lines, line)
	}
	blocks = append(blocks, cur)

	// Second pass: append missing keys to existing sections
	existingSecs := map[string]int{}
	for i, b := range blocks {
		existingSecs[b.name] = i
	}
	var secNames []string
	for s := range updates {
		secNames = append(secNames, s)
	}
	sort.Strings(secNames)

	for _, sec := range secNames {
		var keys []string
		for k := range updates[sec] {
			if !applied[sec][k] {
				keys = append(keys, k)
			}
		}
		sort.Strings(keys)
		if len(keys) == 0 {
			continue
		}
		if idx, ok := existingSecs[sec]; ok {
			for _, k := range keys {
				blocks[idx].lines = append(blocks[idx].lines, fmt.Sprintf("%s = %s", k, updates[sec][k]))
			}
		} else {
			nb := secBlock{name: sec}
			if sec != "" {
				nb.lines = append(nb.lines, "", fmt.Sprintf("[%s]", sec))
			}
			for _, k := range keys {
				nb.lines = append(nb.lines, fmt.Sprintf("%s = %s", k, updates[sec][k]))
			}
			blocks = append(blocks, nb)
		}
	}

	if err := os.MkdirAll(filepath.Dir(*cfgPath), 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "environment-to-ini: mkdir failed: %v\n", err)
		os.Exit(1)
	}
	var out []string
	for _, b := range blocks {
		out = append(out, b.lines...)
	}
	content := strings.TrimLeft(strings.Join(out, "\n"), "\n") + "\n"
	if err := os.WriteFile(*cfgPath, []byte(content), 0o640); err != nil {
		fmt.Fprintf(os.Stderr, "environment-to-ini: write failed: %v\n", err)
		os.Exit(1)
	}
}
