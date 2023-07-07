package main

import (
	"bytes"
	"fmt"
	"strings"
	"strconv"
        "encoding/binary"
	"github.com/tidwall/gjson"
	"github.com/tetratelabs/proxy-wasm-go-sdk/proxywasm"
	"github.com/tetratelabs/proxy-wasm-go-sdk/proxywasm/types"
)

func main() {
	proxywasm.SetVMContext(&vmContext{})
}

type vmContext struct {
	// Embed the default VM context here,
	// so that we don't need to reimplement all the methods.
	types.DefaultVMContext
}

func (*vmContext) NewPluginContext(contextID uint32) types.PluginContext {
	return &pluginContext{}
}

type pluginContext struct {
	// Embed the default plugin context here,
	// so that we don't need to reimplement all the methods.
	types.DefaultPluginContext
	configuration pluginConfiguration
}

type pluginConfiguration struct {
	// Example configuration field.
	// The plugin will validate if those fields exist in the json payload.
	attributes []string
}

func (ctx *pluginContext) OnPluginStart(pluginConfigurationSize int) types.OnPluginStartStatus {
	data, err := proxywasm.GetPluginConfiguration()
	if err != nil && err != types.ErrorStatusNotFound {
		proxywasm.LogCriticalf("error reading plugin configuration: %v", err)
		return types.OnPluginStartStatusFailed
	}
	config, err := parsePluginConfiguration(data)
	if err != nil {
		proxywasm.LogCriticalf("error parsing plugin configuration: %v", err)
		return types.OnPluginStartStatusFailed
	}
	ctx.configuration = config
	return types.OnPluginStartStatusOK
}

func parsePluginConfiguration(data []byte) (pluginConfiguration, error) {
	if len(data) == 0 {
		return pluginConfiguration{}, nil
	}

	config := &pluginConfiguration{}
	if !gjson.ValidBytes(data) {
		return pluginConfiguration{}, fmt.Errorf("the plugin configuration is not a valid json: %q", string(data))
	}

	jsonData := gjson.ParseBytes(data)
	attributes := jsonData.Get("attributes").Array()
	for _, attribute := range attributes {
		config.attributes = append(config.attributes, attribute.Str)
	}

	return *config, nil
}

func (ctx *pluginContext) NewHttpContext(contextID uint32) types.HttpContext {
	return &payloadValidationContext{attributes: ctx.configuration.attributes}
}

// payloadValidationContext implements types.HttpContext interface of proxy-wasm-go SDK.
type payloadValidationContext struct {
	// Embed the default root http context here,
	// so that we don't need to reimplement all the methods.
	types.DefaultHttpContext
	attributes         []string
}

var _ types.HttpContext = (*payloadValidationContext)(nil)

func ConvertBytesToValue(data []byte) string {
	switch {
	case len(data) == 1:
		// Interpret as a boolean and convert to string.
		return strconv.FormatBool(data[0] != 0)
	case len(data) >= 2:
		// If all bytes after the second are null, interpret the first two bytes as a TCP port (uint16).
		if len(data) == 2 || bytes.Equal(data[2:], make([]byte, len(data)-2)) {
			return strconv.FormatUint(uint64(binary.LittleEndian.Uint16(data[0:2])), 10)
		}
		fallthrough
	default:
		// Otherwise, interpret as a string.
		return string(data)
	}
}

func toCamelCase(input string) string {
	titleCase := strings.Title(input)
	return strings.ReplaceAll(titleCase, " ", "")
}

func processHeader(header string) string {
	// Splitting the header string into parts
	parts := strings.Split(header, "-")

	// Converting each part into Camel Case
	for i, part := range parts {
		parts[i] = toCamelCase(part)
	}

	// Joining the parts back into a single string
	return strings.Join(parts, "-")
}

func (ctx *payloadValidationContext) OnHttpRequestHeaders(numHeaders int, endOfStream bool) types.Action {
	for _, attribute := range ctx.attributes {
		proxywasm.LogInfof("adding header for %s", attribute)

		attributeValue, err := proxywasm.GetProperty([]string{strings.Split(attribute, ".")[0], strings.Split(attribute, ".")[1]})
		if err != nil {
			proxywasm.LogWarnf("failed to get attribute: %v", err)
		}

		headerName := "X-Attribute-" + strings.Split(attribute, ".")[0] + "-" + strings.Split(attribute, ".")[1]
		headerName = strings.ReplaceAll(headerName, "_", "-")
		headerName = processHeader(headerName)
proxywasm.LogInfof("%s", headerName)


		// Add the attributeValue as a header
		if err := proxywasm.AddHttpRequestHeader(headerName, ConvertBytesToValue(attributeValue)); err != nil {
			proxywasm.LogCriticalf("failed to set response constant header: %v", err)
		}
	}

	// Get and log the headers
	hs, err := proxywasm.GetHttpRequestHeaders()
	if err != nil {
		proxywasm.LogCriticalf("failed to get request headers: %v", err)
	}

	for _, h := range hs {
		proxywasm.LogInfof("request header <-- %s: %s", h[0], h[1])
	}
	return types.ActionContinue
}