package app.termora

import app.termora.keymgr.OhKeyPairKeyPairProvider
import app.termora.terminal.TerminalSize
import org.apache.sshd.client.ClientBuilder
import org.apache.sshd.client.SshClient
import org.apache.sshd.client.channel.ChannelShell
import org.apache.sshd.client.session.ClientSession
import org.apache.sshd.common.SshException
import org.apache.sshd.common.channel.PtyChannelConfiguration
import org.apache.sshd.common.global.KeepAliveHandler
import org.apache.sshd.core.CoreModuleProperties
import org.apache.sshd.server.forward.AcceptAllForwardingFilter
import org.apache.sshd.server.forward.RejectAllForwardingFilter
import org.eclipse.jgit.internal.transport.sshd.JGitSshClient
import org.eclipse.jgit.transport.CredentialsProvider
import org.eclipse.jgit.transport.sshd.IdentityPasswordProvider
import org.eclipse.jgit.transport.sshd.ProxyData
import java.net.InetSocketAddress
import java.net.Proxy
import java.time.Duration

object SshClients {
    private val timeout = Duration.ofSeconds(30)

    /**
     * 打开一个 Shell
     */
    fun openShell(
        host: Host,
        size: TerminalSize,
        session: ClientSession,
    ): ChannelShell {


        val configuration = PtyChannelConfiguration()
        configuration.ptyColumns = size.cols
        configuration.ptyLines = size.rows
        configuration.ptyType = "xterm-256color"

        val env = mutableMapOf<String, String>()
        env["TERM"] = configuration.ptyType
        env.putAll(host.options.envs())

        val channel = session.createShellChannel(configuration, env)
        if (!channel.open().verify(timeout).await()) {
            throw SshException("Failed to open Shell")
        }

        return channel

    }

    /**
     * 打开一个会话
     */
    fun openSession(host: Host, client: SshClient): ClientSession {
        val session = client.connect(host.username, host.host, host.port)
            .verify(timeout).session
        if (host.authentication.type == AuthenticationType.Password) {
            session.addPasswordIdentity(host.authentication.password)
        } else if (host.authentication.type == AuthenticationType.PublicKey) {
            session.keyIdentityProvider = OhKeyPairKeyPairProvider(host.authentication.password)
        }
        if (!session.auth().verify(timeout).await(timeout)) {
            throw SshException("Authentication failed")
        }
        return session
    }

    /**
     * 打开一个客户端
     */
    fun openClient(host: Host): SshClient {
        val builder = ClientBuilder.builder()
        builder.globalRequestHandlers(listOf(KeepAliveHandler.INSTANCE))
            .factory { JGitSshClient() }

        if (host.tunnelings.isEmpty()) {
            builder.forwardingFilter(RejectAllForwardingFilter.INSTANCE)
        } else {
            builder.forwardingFilter(AcceptAllForwardingFilter.INSTANCE)
        }

        val sshClient = builder.build() as JGitSshClient
        CoreModuleProperties.HEARTBEAT_INTERVAL.set(sshClient, timeout)
        sshClient.setKeyPasswordProviderFactory { IdentityPasswordProvider(CredentialsProvider.getDefault()) }

        if (host.proxy.type != ProxyType.No) {
            sshClient.setProxyDatabase {
                if (host.proxy.authenticationType == AuthenticationType.No) ProxyData(
                    Proxy(
                        Proxy.Type.SOCKS,
                        InetSocketAddress(host.proxy.host, host.proxy.port)
                    )
                )
                else
                    ProxyData(
                        Proxy(
                            Proxy.Type.SOCKS,
                            InetSocketAddress(host.proxy.host, host.proxy.port)
                        ),
                        host.proxy.username,
                        host.proxy.password.toCharArray(),
                    )
            }
        }

        sshClient.start()
        return sshClient
    }
}