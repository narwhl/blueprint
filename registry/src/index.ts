import { Context, Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { logger } from 'hono/logger';
import { requestId } from 'hono/request-id';
import { bearerAuth } from 'hono/bearer-auth';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { discoveryRequest, processDiscoveryResponse } from 'oauth4webapi';
import semver from 'semver';

interface Bindings {
	modules: KVNamespace;
	artifact: R2Bucket;
}

interface CreateModuleRequest {
	name: string;
	namespace: string;
	provider: string;
	description: string;
	owner: string;
	source: string;
}

interface Module extends CreateModuleRequest {
	id: string;
	verified: boolean;
	downloads: number;
	published_at: string;
	versions: string[];
}

const basePath = '/v1/modules';

const app = new Hono<{ Bindings: Bindings }>();
const registry = new Hono().basePath(basePath);

app.use(logger());
app.use('*', requestId());

const serviceDiscoveryResponse = {
	'modules.v1': `${basePath}/`,
};

app.get('/healthz', async (context: Context) => context.json({ status: 'ok' }));
app.get('/', async (context: Context) => context.redirect('/.well-known/terraform.json'));
app.get('/.well-known/terraform.json', async (context: Context) => context.json(serviceDiscoveryResponse));
app.get('/v1/metadata', async (context: Context) => {
	const metadata = await context.env.modules.get('metadata');
	return context.body(metadata || '{}', 200, { 'Content-Type': 'application/json' });
});

async function verifyToken(token: string, context: Context) {
	try {
		const url = new URL('https://token.actions.githubusercontent.com');
		const response = await discoveryRequest(url);
		const authorizationServer = await processDiscoveryResponse(url, response);
		const jwks = createRemoteJWKSet(new URL(authorizationServer.jwks_uri!));
		await jwtVerify(token, jwks, {
			issuer: authorizationServer.issuer,
			audience: 'https://github.com/narwhl',
			algorithms: ['RS256'],
		});
		return true;
	} catch (error) {
		return false;
	}
}

registry.post(`/`, bearerAuth({ verifyToken }), async (context: Context) => {
	const payload: CreateModuleRequest = await context.req.json();
	const { modules } = context.env as Bindings;
	const metadata = await modules.get<{ [key: string]: string }>('metadata', 'json');
	const id = crypto.randomUUID();
	if (metadata) {
		metadata[payload.source] = `${payload.namespace}/${payload.name}/${payload.provider}`;
		await Promise.all([
			modules.put(
				`modules:${payload.namespace}/${payload.name}/${payload.provider}`,
				JSON.stringify({
					...payload,
					id,
					verified: true,
					downloads: 0,
					published_at: new Date().toISOString(),
				})
			),
			modules.put('metadata', JSON.stringify(metadata)),
		]);
		return context.json(
			{
				id,
				published_at: new Date().toISOString(),
			},
			201
		);
	} else {
		throw new HTTPException(500, {
			message: 'metadata not found',
		});
	}
});

async function getVersions(context: Context, selector: string) {
	const result: R2Objects = await context.env.artifact.list({
		prefix: `modules/${selector}/`,
	});
	return result.objects.map((object) =>
		object.key
			.split('/')
			.reverse()[0]
			.replace(/\.tgz$|\.zip|\.tar.gz$/, '')
	);
}

registry.post(`/:namespace/:name/:provider/versions`, bearerAuth({ verifyToken }), async (context: Context) => {
	const { namespace, name, provider } = context.req.param();
	const { modules, artifact } = context.env as Bindings;
	const body = await context.req.parseBody();
	const selector = `${namespace}/${name}/${provider}`;
	const module = await modules.get<Module>(`modules:${selector}`, 'json');
	if (module) {
		var nextVersion = '1.0.0';
		if (module.versions.length > 0) {
			nextVersion = semver.inc(module.versions[0], body['increment'] as semver.ReleaseType)!;
		}
		await Promise.all([
			artifact.put(`modules/${selector}/${nextVersion}.tar.gz`, body['module']),
			modules.put(
				`modules:${selector}`,
				JSON.stringify({
					...module,
					versions: [nextVersion, ...module.versions],
					published_at: new Date().toISOString(),
				})
			),
		]);
		return context.json(
			{
				status: 'ok',
				module: `registry.narwhl.workers.dev/${selector}`,
				version: nextVersion,
			},
			201
		);
	} else {
		return context.json(
			{
				status: 'error',
				message: 'module not found',
			},
			404
		);
	}
});

registry.get(`/:namespace/:name/:provider/versions`, async (context: Context) => {
	const { name, namespace, provider } = context.req.param();
	const versions = await getVersions(context, `${namespace}/${name}/${provider}`);
	if (versions.length > 0) {
		return context.json({
			source: `${namespace}/${name}/${provider}`,
			modules: [
				{
					versions: versions.map((version: string) => ({
						version,
					})),
				},
			],
		});
	} else {
		return context.json(
			{
				status: 'error',
				message: 'module not found',
			},
			404
		);
	}
});

registry.get(`/:namespace/:name/:provider/download`, async (context: Context) => {
	try {
		const { ...params } = context.req.param();
		const { modules } = context.env as Bindings;
		const selector = Object.values(params).join('/');
		const module = await modules.get<Module>(`modules:${selector}`, 'json');
		if (module) {
			await modules.put(
				`modules:${selector}`,
				JSON.stringify({
					...module,
					downloads: module.downloads + 1,
				})
			);
			context.header('X-Terraform-Get', `https://artifact.narwhl.dev/modules/${selector}/${module.versions[0]}.tar.gz`);
			return context.body(null, 204);
		} else {
			return context.json(
				{
					status: 'error',
					message: 'module not found',
				},
				404
			);
		}
	} catch (error) {
		throw new HTTPException(500, {
			message: `internal server error ${JSON.stringify(error)}`,
		});
	}
});

registry.get(`/:namespace/:name/:provider/:version/download`, async (context: Context) => {
	const { version, ...params } = context.req.param();
	const { artifact, modules } = context.env as Bindings;
	const selector = Object.values(params).join('/');
	const result = await artifact.list({
		prefix: `modules/${selector}/${version}`,
	});
	if (result.objects.length > 0) {
		const module = await modules.get<Module>(`modules:${selector}`, 'json');
		await context.env.modules.put(
			`modules:${selector}`,
			JSON.stringify({
				...module,
				downloads: module!.downloads + 1,
			})
		);
		context.header('X-Terraform-Get', `https://artifact.narwhl.dev/${result.objects[0].key}`);
		return context.body(null, 204);
	} else {
		return context.json(
			{
				status: 'error',
				message: 'module not found',
			},
			404
		);
	}
});

app.route('/', registry);
export default app;
