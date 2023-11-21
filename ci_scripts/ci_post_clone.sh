#!/bin/sh

echo "Rewriting Release.xcconfig file"
echo "DEVELOPMENT_TEAM = $DEVELOPMENT_TEAM" > ../BuildConfiguration/Release.xcconfig
echo "BP_ENTITLEMENTS = $BP_ENTITLEMENTS" >> ../BuildConfiguration/Release.xcconfig
echo "BP_BUNDLE_IDENTIFIER = $BP_BUNDLE_IDENTIFIER" >> ../BuildConfiguration/Release.xcconfig
echo "BP_PROVISIONING_MAIN = $BP_PROVISIONING_MAIN" >> ../BuildConfiguration/Release.xcconfig
echo "BP_PROVISIONING_WIDGET = $BP_PROVISIONING_WIDGET" >> ../BuildConfiguration/Release.xcconfig
echo "BP_PROVISIONING_WATCH = $BP_PROVISIONING_WATCH" >> ../BuildConfiguration/Release.xcconfig
echo "BP_PROVISIONING_WATCH_WIDGETS = $BP_PROVISIONING_WATCH_WIDGETS" >> ../BuildConfiguration/Release.xcconfig
echo "BP_PROVISIONING_INTENTS = $BP_PROVISIONING_INTENTS" >> ../BuildConfiguration/Release.xcconfig
echo "BP_PROVISIONING_WIDGET_UI = $BP_PROVISIONING_WIDGET_UI" >> ../BuildConfiguration/Release.xcconfig
echo "BP_PROVISIONING_WATCH_WIDGET_UI = $BP_PROVISIONING_WATCH_WIDGET_UI" >> ../BuildConfiguration/Release.xcconfig
echo "BP_PROVISIONING_SHARE_EXTENSION = $BP_PROVISIONING_SHARE_EXTENSION" >> ../BuildConfiguration/Release.xcconfig
echo "BP_SENTRY_DSN = $BP_SENTRY_DSN" >> ../BuildConfiguration/Release.xcconfig
echo "BP_REVENUECAT_KEY = $BP_REVENUECAT_KEY" >> ../BuildConfiguration/Release.xcconfig
echo "BP_MOCKED_BEARER_TOKEN = $BP_MOCKED_BEARER_TOKEN" >> ../BuildConfiguration/Release.xcconfig
echo "BP_API_SCHEME = $BP_API_SCHEME" >> ../BuildConfiguration/Release.xcconfig
echo "BP_API_DOMAIN = $BP_API_DOMAIN" >> ../BuildConfiguration/Release.xcconfig
echo "BP_API_PORT = $BP_API_PORT" >> ../BuildConfiguration/Release.xcconfig
