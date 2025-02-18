import { useSettingsStore } from "@/store/settings";
import { SettingsSection, SettingRow } from "./SettingsSection";
import { useSession } from "next-auth/react";
import { BsGoogle } from "react-icons/bs";

export function IntegrationSettings() {
  const { data: session } = useSession();
  const { integrations, updateIntegrationSettings } = useSettingsStore();

  return (
    <SettingsSection
      title="Integration Settings"
      description="Manage your calendar integrations and synchronization settings."
    >
      <SettingRow
        label="Google Calendar"
        description="Configure your Google Calendar integration"
      >
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <BsGoogle className="h-6 w-6 text-gray-500" />
              <div>
                <div className="font-medium">Google Calendar</div>
                <div className="text-sm text-gray-500">
                  {session?.user?.email || "Not connected"}
                </div>
              </div>
            </div>
            <label className="relative inline-flex items-center cursor-pointer">
              <input
                type="checkbox"
                checked={integrations.googleCalendar.enabled}
                onChange={(e) =>
                  updateIntegrationSettings({
                    googleCalendar: {
                      ...integrations.googleCalendar,
                      enabled: e.target.checked,
                    },
                  })
                }
                className="sr-only peer"
              />
              <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
            </label>
          </div>

          {integrations.googleCalendar.enabled && (
            <>
              <label className="flex items-center">
                <input
                  type="checkbox"
                  checked={integrations.googleCalendar.autoSync}
                  onChange={(e) =>
                    updateIntegrationSettings({
                      googleCalendar: {
                        ...integrations.googleCalendar,
                        autoSync: e.target.checked,
                      },
                    })
                  }
                  className="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                />
                <span className="ml-2 text-sm">Enable auto-sync</span>
              </label>

              <div>
                <label className="block text-sm font-medium text-gray-700">
                  Sync Interval (minutes)
                </label>
                <input
                  type="number"
                  min="1"
                  max="60"
                  value={integrations.googleCalendar.syncInterval}
                  onChange={(e) =>
                    updateIntegrationSettings({
                      googleCalendar: {
                        ...integrations.googleCalendar,
                        syncInterval: Number(e.target.value),
                      },
                    })
                  }
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                />
              </div>
            </>
          )}
        </div>
      </SettingRow>
    </SettingsSection>
  );
}
