/* eslint-disable n8n-nodes-base/node-dirname-against-convention */
import type { Embeddings } from '@langchain/core/embeddings';
import {
	NodeConnectionTypes,
	type INodeType,
	type INodeTypeDescription,
	type ISupplyDataFunctions,
	type SupplyData,
} from 'n8n-workflow';

import { logWrapper } from '@utils/logWrapper';

import { MemoryVectorStoreManager } from '../shared/MemoryManager/MemoryVectorStoreManager';

// This node is deprecated. Use VectorStoreInMemory instead.
export class VectorStoreInMemoryLoad implements INodeType {
	description: INodeTypeDescription = {
		displayName: 'In Memory Vector Store Load',
		name: 'vectorStoreInMemoryLoad',
		icon: 'fa:database',
		group: ['transform'],
		version: 1,
		hidden: true,
		description: 'Load embedded data from an in-memory vector store',
		defaults: {
			name: 'In Memory Vector Store Load',
		},
		codex: {
			categories: ['AI'],
			subcategories: {
				AI: ['Vector Stores'],
			},
			resources: {},
		},
		// eslint-disable-next-line n8n-nodes-base/node-class-description-inputs-wrong-regular-node
		inputs: [
			{
				displayName: 'Embedding',
				maxConnections: 1,
				type: NodeConnectionTypes.AiEmbedding,
				required: true,
			},
		],
		outputs: [NodeConnectionTypes.AiVectorStore],
		outputNames: ['Vector Store'],
		properties: [
			{
				displayName: 'Memory Key',
				name: 'memoryKey',
				type: 'string',
				default: 'vector_store_key',
				description:
					'The key to use to store the vector memory in the workflow data. The key will be prefixed with the workflow ID to avoid collisions.',
			},
		],
	};

	async supplyData(this: ISupplyDataFunctions, itemIndex: number): Promise<SupplyData> {
		const embeddings = (await this.getInputConnectionData(
			NodeConnectionTypes.AiEmbedding,
			itemIndex,
		)) as Embeddings;

		const workflowId = this.getWorkflow().id;
		const memoryKey = this.getNodeParameter('memoryKey', 0) as string;

		const vectorStoreSingleton = MemoryVectorStoreManager.getInstance(embeddings, this.logger);
		const vectorStoreInstance = await vectorStoreSingleton.getVectorStore(
			`${workflowId}__${memoryKey}`,
		);

		return {
			response: logWrapper(vectorStoreInstance, this),
		};
	}
}
