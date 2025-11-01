using System;
using System.Linq;
using Godot;

namespace CABMED.scripts.utils;

public partial class CosineSimilarity : GodotObject
{
	private double _norm;

	private void SetVector(double[] vector)
	{
		var sumOfSquares= vector.Sum(element => element * element);
		_norm = Math.Sqrt(sumOfSquares);
	}
	/// <summary>
	/// 计算两个向量的余弦相似度（安全代码，带边界检查）
	/// </summary>
	private double Calculate(double[] vectorA, double[] vectorB)
	{
		// 检查向量长度是否一致
		if (vectorA.Length != vectorB.Length)
			throw new ArgumentException("向量长度必须相等");

		double dotProduct = 0;
		double normA = 0;
		double normB = 0;
		// 单次循环计算点积和范数（减少缓存未命中）
		for (var i = 0; i < vectorA.Length; i++)
		{
			dotProduct += vectorA[i] * vectorB[i];
			normA += vectorA[i] * vectorA[i];
			normB += vectorB[i] * vectorB[i];
		}

		// 避免除以零（若范数为0，返回0表示无相似性）
		if (normA == 0 || normB == 0)
			return 0;

		return dotProduct / (Math.Sqrt(normA) * Math.Sqrt(normB));
	}
}
