/*
Copyright 2024.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package main

import (
	"crypto/tls"
	"flag"
	"os"
	"runtime"
	"time"

	// Import all Kubernetes client auth plugins (e.g. Azure, GCP, OIDC, etc.)
	"github.com/operator-framework/helm-operator-plugins/pkg/annotation"
	"github.com/operator-framework/helm-operator-plugins/pkg/reconciler"
	"github.com/operator-framework/helm-operator-plugins/pkg/watches"
	_ "k8s.io/client-go/plugin/pkg/client/auth"

	ctrlruntime "k8s.io/apimachinery/pkg/runtime"
	utilruntime "k8s.io/apimachinery/pkg/util/runtime"
	clientgoscheme "k8s.io/client-go/kubernetes/scheme"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/healthz"
	"sigs.k8s.io/controller-runtime/pkg/log/zap"
	metricsserver "sigs.k8s.io/controller-runtime/pkg/metrics/server"
	"sigs.k8s.io/controller-runtime/pkg/webhook"

	netv1 "gradiant/open5gs-legacy-operator/api/v1"
	"gradiant/open5gs-legacy-operator/internal/controller"
	//+kubebuilder:scaffold:imports
)

var (
	scheme                         = ctrlruntime.NewScheme()
	setupLog                       = ctrl.Log.WithName("setup")
	defaultMaxConcurrentReconciles = runtime.NumCPU()
	defaultReconcilePeriod         = time.Minute
)

func init() {
	utilruntime.Must(clientgoscheme.AddToScheme(scheme))

	utilruntime.Must(netv1.AddToScheme(scheme))
	//+kubebuilder:scaffold:scheme
}

func main() {
	var (
		metricsAddr          string
		leaderElectionID     string
		watchesPath          string
		probeAddr            string
		enableLeaderElection bool
		enableHTTP2          bool
		secureMetrics        bool
	)

	flag.StringVar(&metricsAddr, "metrics-bind-address", ":8080", "The address the metric endpoint binds to.")
	flag.StringVar(&probeAddr, "health-probe-bind-address", ":8081", "The address the probe endpoint binds to.")
	flag.StringVar(&watchesPath, "watches-file", "watches.yaml", "path to watches file")
	flag.StringVar(&leaderElectionID, "leader-election-id", "7becc4b8.gradiant.org", "provide leader election")
	flag.BoolVar(&enableLeaderElection, "leader-elect", false,
		"Enable leader election for controller manager. "+
			"Enabling this will ensure there is only one active controller manager.")
	flag.BoolVar(&secureMetrics, "metrics-secure", false,
		"Whether or not the metrics endpoint should be served securely")
	flag.BoolVar(&enableHTTP2, "enable-http2", false,
		"Whether or not HTTP/2 should be enabled for the metrics and webhook servers")
	opts := zap.Options{
		Development: true,
	}
	opts.BindFlags(flag.CommandLine)
	flag.Parse()

	ctrl.SetLogger(zap.New(zap.UseFlagOptions(&opts)))

	disableHTTP2 := func(c *tls.Config) {
		setupLog.Info("disabling http/2")
		c.NextProtos = []string{"http/1.1"}
	}

	tlsOpts := []func(*tls.Config){}
	if !enableHTTP2 {
		tlsOpts = append(tlsOpts, disableHTTP2)
	}

	webhookServer := webhook.NewServer(webhook.Options{
		TLSOpts: tlsOpts,
	})

	mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
		Scheme: scheme,
		Metrics: metricsserver.Options{
			BindAddress:   metricsAddr,
			SecureServing: secureMetrics,
			TLSOpts:       tlsOpts,
		},
		WebhookServer:          webhookServer,
		HealthProbeBindAddress: probeAddr,
		LeaderElection:         enableLeaderElection,
		LeaderElectionID:       leaderElectionID,
	})
	if err != nil {
		setupLog.Error(err, "unable to start manager")
		os.Exit(1)
	}

	if err = (&controller.Open5GSUserReconciler{
		Client: mgr.GetClient(),
		Scheme: mgr.GetScheme(),
	}).SetupWithManager(mgr); err != nil {
		setupLog.Error(err, "unable to create controller", "controller", "Open5GSUser")
		os.Exit(1)
	}
	//+kubebuilder:scaffold:builder

	if err := mgr.AddHealthzCheck("healthz", healthz.Ping); err != nil {
		setupLog.Error(err, "unable to set up health check")
		os.Exit(1)
	}
	if err := mgr.AddReadyzCheck("readyz", healthz.Ping); err != nil {
		setupLog.Error(err, "unable to set up ready check")
		os.Exit(1)
	}

	ws, err := watches.Load(watchesPath)
	if err != nil {
		setupLog.Error(err, "Failed to create new manager factories")
		os.Exit(1)
	}

	for _, w := range ws {
		// Register controller with the factory
		reconcilePeriod := defaultReconcilePeriod
		if w.ReconcilePeriod != nil {
			reconcilePeriod = w.ReconcilePeriod.Duration
		}

		maxConcurrentReconciles := defaultMaxConcurrentReconciles
		if w.MaxConcurrentReconciles != nil {
			maxConcurrentReconciles = *w.MaxConcurrentReconciles
		}

		r, err := reconciler.New(
			reconciler.WithChart(*w.Chart),
			reconciler.WithGroupVersionKind(w.GroupVersionKind),
			reconciler.WithOverrideValues(w.OverrideValues),
			reconciler.SkipDependentWatches(w.WatchDependentResources != nil && !*w.WatchDependentResources),
			reconciler.WithMaxConcurrentReconciles(maxConcurrentReconciles),
			reconciler.WithReconcilePeriod(reconcilePeriod),
			reconciler.WithInstallAnnotations(annotation.DefaultInstallAnnotations...),
			reconciler.WithUpgradeAnnotations(annotation.DefaultUpgradeAnnotations...),
			reconciler.WithUninstallAnnotations(annotation.DefaultUninstallAnnotations...),
		)
		if err != nil {
			setupLog.Error(err, "unable to create helm reconciler", "controller", "Helm")
			os.Exit(1)
		}
		if err := r.SetupWithManager(mgr); err != nil {
			setupLog.Error(err, "unable to create controller", "controller", "Helm")
			os.Exit(1)
		}
		setupLog.Info("configured watch", "gvk", w.GroupVersionKind, "chartPath", w.ChartPath, "maxConcurrentReconciles", maxConcurrentReconciles, "reconcilePeriod", reconcilePeriod)
	}

	setupLog.Info("starting manager")
	if err := mgr.Start(ctrl.SetupSignalHandler()); err != nil {
		setupLog.Error(err, "problem running manager")
		os.Exit(1)
	}
}
