using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

public static class BuildCommand
{
    private static string[] GetEnabledScenes()
    {
        List<string> scenes = new List<string>();
        foreach (EditorBuildSettingsScene scene in EditorBuildSettings.scenes)
        {
            if (scene.enabled)
            {
                scenes.Add(scene.path);
            }
        }
        return scenes.ToArray();
    }

    [MenuItem("Build/Build Linux 64")]
    public static void PerformBuildLinux64()
    {
        PerformBuild("Builds/StandaloneLinux64/CardWars.x86_64", BuildTarget.StandaloneLinux64);
    }

    [MenuItem("Build/Build Windows 64")]
    public static void PerformBuildWindows64()
    {
        PerformBuild("Builds/StandaloneWindows64/CardWars.exe", BuildTarget.StandaloneWindows64);
    }

    [MenuItem("Build/Build macOS")]
    public static void PerformBuildOSX()
    {
        PerformBuild("Builds/StandaloneOSX/CardWars.app", BuildTarget.StandaloneOSX);
    }

    public static void PerformBuild(string locationPathName, BuildTarget buildTarget)
    {
        string[] scenes = GetEnabledScenes();
        if (scenes.Length == 0)
        {
            throw new InvalidOperationException("No enabled scenes found in EditorBuildSettings!");
        }

        string directory = Path.GetDirectoryName(locationPathName);
        if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
        {
            Directory.CreateDirectory(directory);
        }

        BuildPlayerOptions buildPlayerOptions = new BuildPlayerOptions
        {
            scenes = scenes,
            locationPathName = locationPathName,
            target = buildTarget,
            options = BuildOptions.None
        };

        Debug.Log(string.Format("[BuildCommand] Building {0} to {1} with {2} scenes...", buildTarget, locationPathName, scenes.Length));

#if UNITY_2018_1_OR_NEWER
        var report = BuildPipeline.BuildPlayer(buildPlayerOptions);
        if (report.summary.result != UnityEditor.Build.Reporting.BuildResult.Succeeded)
        {
            throw new Exception("[BuildCommand] Build failed: " + report.summary.result);
        }
#else
        string error = BuildPipeline.BuildPlayer(buildPlayerOptions);
        if (!string.IsNullOrEmpty(error))
        {
            throw new Exception("[BuildCommand] Build failed: " + error);
        }
#endif
        Debug.Log("[BuildCommand] Build completed successfully: " + locationPathName);
    }
}
